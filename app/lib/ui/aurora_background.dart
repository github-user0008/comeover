import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/device.dart';
import '../core/theme.dart';

/// Animated backdrop. Android gets a vivid, faster-moving Material 3
/// Expressive wash; Apple platforms get a slow, low-chroma graphite haze so the
/// glass surfaces above it stay the star.
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

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();
  bool _periodApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_periodApplied) return;
    _periodApplied = true;
    final period = AppStyle.of(context).backgroundPeriod;
    if (period != _controller.duration) {
      _controller.duration = period;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final style = AppStyle.of(context);
    final painter = _AuroraPainter(
      t: reduceMotion ? 0.35 : _controller.value,
      dark: widget.dark,
      intensity: widget.intensity,
      style: style,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) =>
                CustomPaint(painter: painter, isComplex: true),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.dark,
    required this.intensity,
    required this.style,
  });

  final double t;
  final bool dark;
  final double intensity;
  final AppStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = dark
        ? style.background
        : Color.lerp(style.background, Colors.white, 0.45)!;
    canvas.drawRect(rect, Paint()..color = base);

    final angle = t * math.pi * 2;
    final minDim = size.shortestSide;

    if (style.isMaterial) {
      _paintMaterial(canvas, size, minDim, angle, base);
    } else {
      _paintLiquid(canvas, size, minDim, angle, base);
    }
  }

  void _paintMaterial(
    Canvas canvas,
    Size size,
    double minDim,
    double angle,
    Color base,
  ) {
    final strength = intensity * style.auroraStrength;
    if (dark) {
      _blob(
        canvas,
        size,
        center: Offset(
          size.width * (0.82 + math.sin(angle) * 0.09),
          size.height * (0.04 + math.cos(angle * 0.8) * 0.06),
        ),
        radius: minDim * 1.05,
        color: style.auroraPrimary.withValues(alpha: 0.62 * strength),
      );
      _blob(
        canvas,
        size,
        center: Offset(
          size.width * (0.08 + math.cos(angle * 0.7) * 0.11),
          size.height * (0.90 + math.sin(angle * 0.9) * 0.07),
        ),
        radius: minDim * 0.95,
        color: style.auroraSecondary.withValues(alpha: 0.40 * strength),
      );
      _blob(
        canvas,
        size,
        center: Offset(
          size.width * (0.46 + math.sin(angle * 0.5 + 2) * 0.24),
          size.height * (0.46 + math.cos(angle * 0.6) * 0.20),
        ),
        radius: minDim * 0.62,
        color: style.auroraTertiary.withValues(alpha: 0.24 * strength),
      );
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.62, size.height * 1.08),
        radius: minDim * 0.78,
        color: style.brand.withValues(alpha: 0.38 * strength),
      );
      canvas.drawRect(
        rectFor(size),
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 1.05,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.42)],
            stops: const [0.48, 1],
          ).createShader(rectFor(size)),
      );
      // Expressive top light keeps the first screen from feeling muddy.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.42),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.07 * strength),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.42)),
      );
    } else {
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.86, size.height * 0.08),
        radius: minDim * 1.1,
        color: style.auroraPrimary.withValues(alpha: 0.24 * strength),
      );
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.06, size.height * 0.94),
        radius: minDim * 1.05,
        color: style.auroraSecondary.withValues(alpha: 0.20 * strength),
      );
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.48, size.height * 0.48),
        radius: minDim * 0.8,
        color: style.auroraTertiary.withValues(alpha: 0.14 * strength),
      );
    }
  }

  void _paintLiquid(
    Canvas canvas,
    Size size,
    double minDim,
    double angle,
    Color base,
  ) {
    final strength = intensity * style.auroraStrength;
    if (dark) {
      _blob(
        canvas,
        size,
        center: Offset(
          size.width * (0.78 + math.sin(angle * 0.6) * 0.05),
          size.height * (0.10 + math.cos(angle * 0.5) * 0.04),
        ),
        radius: minDim * 1.35,
        color: style.auroraPrimary.withValues(alpha: 0.30 * strength),
      );
      _blob(
        canvas,
        size,
        center: Offset(
          size.width * (0.12 + math.cos(angle * 0.45) * 0.06),
          size.height * (0.88 + math.sin(angle * 0.55) * 0.04),
        ),
        radius: minDim * 1.25,
        color: style.auroraSecondary.withValues(alpha: 0.24 * strength),
      );
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.5, size.height * 0.5),
        radius: minDim * 0.8,
        color: style.auroraTertiary.withValues(alpha: 0.10 * strength),
      );
      // Quiet filmic vignette.
      canvas.drawRect(
        rectFor(size),
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 1.15,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
            stops: const [0.38, 1],
          ).createShader(rectFor(size)),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.35),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.055), Colors.transparent],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.35)),
      );
    } else {
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.82, size.height * 0.12),
        radius: minDim * 1.25,
        color: style.auroraPrimary.withValues(alpha: 0.16 * strength),
      );
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.10, size.height * 0.90),
        radius: minDim * 1.2,
        color: style.auroraSecondary.withValues(alpha: 0.13 * strength),
      );
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.5, size.height * 0.55),
        radius: minDim * 0.75,
        color: Colors.white.withValues(alpha: 0.55),
      );
    }
  }

  Rect rectFor(Size size) => Offset.zero & size;

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
      old.t != t ||
      old.dark != dark ||
      old.intensity != intensity ||
      old.style != style;
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
    // TVs overscan up to ~5% per edge; the bottom bezel crops the most, so the
    // margins are asymmetric instead of a uniform inset. Everything that isn't
    // the fullscreen map gets pushed inside the visible picture area. Goes
    // through DeviceProfile so the settings' "TV layout" override applies too.
    final overscan = DeviceProfile.of(context).overscan;
    return SafeArea(
      minimum: overscan,
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
