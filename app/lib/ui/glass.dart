import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme.dart';

/// Liquid glass surface: frosted blur with a soft rim light. Fallback to
/// translucent Material when blur isn't supported or "reduce glass" is on.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 28,
    this.blur = 18,
    this.saturation = 1.6,
    this.tint,
    this.onTap,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double saturation;
  final Color? tint;
  final VoidCallback? onTap;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceGlass = MediaQuery.of(context).disableAnimations;
    final effectiveBlur = reduceGlass ? 0.0 : blur;
    final tintColor = (tint ?? scheme.primary).withValues(alpha: effectiveBlur == 0 ? 0.14 : 0.10);

    Widget surface = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: effectiveBlur == 0 ? 0.10 : 0.16),
                tintColor,
                Colors.black.withValues(alpha: effectiveBlur == 0 ? 0.12 : 0.08),
              ],
              stops: const [0, 0.6, 1],
            ),
            border: border
                ? Border.all(
                    color: Colors.white.withValues(alpha: effectiveBlur == 0 ? 0.18 : 0.28),
                    width: 1,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: effectiveBlur == 0 ? 0.12 : 0.18),
                blurRadius: 40,
                offset: const Offset(0, 22),
              ),
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 60,
                offset: Offset(0, 30),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: RadialGradient(
                center: const Alignment(-0.8, -0.9),
                radius: 1.4,
                colors: [
                  Colors.white.withValues(alpha: effectiveBlur == 0 ? 0.08 : 0.14),
                  Colors.transparent,
                ],
              ),
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (margin != null) surface = Padding(padding: margin!, child: surface);
    if (onTap != null) {
      surface = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: scheme.primary.withValues(alpha: 0.18),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: surface,
        ),
      );
    }
    return surface;
  }
}

/// A pill-shaped frosted chip for status/labels.
class FrostChip extends StatelessWidget {
  const FrostChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = FrostTone.neutral,
    this.compact = false,
  });

  final String label;
  final Widget? icon;
  final FrostTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, bg) = switch (tone) {
      FrostTone.neutral => (scheme.onSurface, scheme.primary),
      FrostTone.live => (const Color(0xFF9BF6FF), Palette.mint),
      FrostTone.alert => (const Color(0xFFFFD6CF), Palette.peach),
      FrostTone.success => (const Color(0xFFD8F3DC), const Color(0xFFB7E4C7)),
    };
    return Glass(
      borderRadius: 999,
      blur: 12,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 6 : 10),
      border: true,
      tint: bg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

enum FrostTone { neutral, live, alert, success }

/// Subtle animated halo behind hero content.
class AmbientHalo extends StatelessWidget {
  const AmbientHalo({
    super.key,
    required this.child,
    this.colors = const [Palette.violet, Palette.mint],
  });

  final Widget child;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AmbientDrift(
              builder: (context, t) {
                final dx = (t - 0.5) * 120;
                final dy = ((1 - t) - 0.5) * 80;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(dx / 400, dy / 400),
                      radius: 1.6,
                      colors: [
                        colors[0].withValues(alpha: 0.22),
                        colors.length > 1 ? colors[1].withValues(alpha: 0.14) : Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0, 0.4, 1],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// TV-friendly focus outline that lights up on focus/hover.
class FocusGlow extends StatefulWidget {
  const FocusGlow({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.enabled = true,
  });

  final Widget child;
  final double borderRadius;
  final bool enabled;

  @override
  State<FocusGlow> createState() => _FocusGlowState();
}

class _FocusGlowState extends State<FocusGlow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    final active = _focused || _hovered;
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.emphasizedDecelerate,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius + 4),
            boxShadow: [
              BoxShadow(
                color: scheme.secondary.withValues(alpha: active ? 0.38 : 0),
                blurRadius: active ? 28 : 0,
                spreadRadius: active ? 2 : 0,
              ),
            ],
          ),
          padding: active ? const EdgeInsets.all(3) : EdgeInsets.zero,
          child: AnimatedContainer(
            duration: Motion.fast,
            curve: Motion.emphasizedDecelerate,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: active ? scheme.secondary.withValues(alpha: 0.9) : Colors.transparent,
                width: 2,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
