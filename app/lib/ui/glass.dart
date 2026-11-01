import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme.dart';

/// A surface that adapts to the platform's visual language.
///
/// * Material 3 Expressive (Android/TV): a tonal, opaque container with a soft
///   gradient, expressive corner radius and an outline — no backdrop blur.
/// * Liquid Glass (iOS/macOS): a deeply blurred pane with a hairline rim, a
///   specular top highlight and a very quiet tint.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur,
    this.saturation = 1.6,
    this.tint,
    this.onTap,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final double? blur;
  final double saturation;
  final Color? tint;
  final VoidCallback? onTap;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    final radius = BorderRadius.circular(borderRadius ?? style.cardRadius);
    final reduce = MediaQuery.of(context).disableAnimations;

    Widget surface;
    if (style.isLiquid && style.useBlur && !reduce) {
      surface = _liquid(
        context,
        scheme,
        style,
        radius,
        blur ?? style.glassBlur,
      );
    } else {
      surface = _tonal(
        context,
        scheme,
        style,
        radius,
        liquidFallback: style.isLiquid,
      );
    }

    if (margin != null) surface = Padding(padding: margin!, child: surface);
    if (onTap != null) {
      surface = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: scheme.primary.withValues(alpha: 0.16),
          highlightColor: scheme.onSurface.withValues(alpha: 0.04),
          child: surface,
        ),
      );
    }
    return surface;
  }

  Widget _tonal(
    BuildContext context,
    ColorScheme scheme,
    AppStyle style,
    BorderRadius radius, {
    required bool liquidFallback,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final sheen = isDark ? Colors.white : Colors.black;
    final base = scheme.surfaceContainerHigh;
    final fill = tint == null
        ? base
        : Color.alphaBlend(
            tint!.withValues(alpha: style.glassTintAlpha + 0.04),
            base,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              sheen.withValues(alpha: liquidFallback ? 0.14 : 0.045),
              fill,
            ),
            fill,
            Color.alphaBlend(
              sheen.withValues(alpha: liquidFallback ? 0.03 : 0.0),
              scheme.surfaceContainer,
            ),
          ],
        ),
        border: border
            ? Border.all(
                color: tint != null
                    ? tint!.withValues(alpha: liquidFallback ? 0.28 : 0.34)
                    : style.chipBorder,
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.10),
            blurRadius: liquidFallback ? 36 : 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _liquid(
    BuildContext context,
    ColorScheme scheme,
    AppStyle style,
    BorderRadius radius,
    double effectiveBlur,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    final tintSource = tint ?? scheme.primary;
    final tintColor = tintSource.withValues(
      alpha: tint != null ? 0.18 : style.glassTintAlpha,
    );
    final rim = (isDark ? Colors.white : Colors.black).withValues(
      alpha: style.glassBorderAlpha,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          if (style.useGlow && tint == null)
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.07),
              blurRadius: 44,
              offset: const Offset(0, 22),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: style.glassShadowAlpha),
            blurRadius: 42,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlur,
            sigmaY: effectiveBlur,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.15),
                        tintColor,
                        Colors.black.withValues(alpha: 0.16),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.72),
                        tintColor,
                        Colors.black.withValues(alpha: 0.035),
                      ],
                stops: const [0, 0.58, 1],
              ),
              border: border
                  ? Border.all(color: rim, width: style.glassBorderWidth)
                  : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: style.glassBorderWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(
                              alpha: style.glassHighlightAlpha,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: padding ?? const EdgeInsets.all(20),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final style = AppStyle.of(context);
    final (color, bg) = switch (tone) {
      FrostTone.neutral => (scheme.onSurface, scheme.primary),
      FrostTone.live => (style.live, style.live),
      FrostTone.alert => (style.warm, style.warm),
      FrostTone.success => (style.live, style.live),
    };
    return Glass(
      borderRadius: 999,
      blur: 12,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 6 : 10,
      ),
      border: true,
      tint: bg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

enum FrostTone { neutral, live, alert, success }

/// Subtle animated halo behind hero content.
class AmbientHalo extends StatelessWidget {
  const AmbientHalo({super.key, required this.child, this.colors});

  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final palette = colors ?? [style.auroraPrimary, style.auroraSecondary];
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
                        palette[0].withValues(alpha: 0.22),
                        palette.length > 1
                            ? palette[1].withValues(alpha: 0.14)
                            : Colors.transparent,
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
                color: active
                    ? scheme.secondary.withValues(alpha: 0.9)
                    : Colors.transparent,
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
