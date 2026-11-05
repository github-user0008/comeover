import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../models/member.dart';
import 'glass.dart';

Color colorFromHex(String hex, [Color fallback = Palette.lavender]) {
  var value = hex.replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

enum ExpressiveTone { filled, tonal, glass, danger }

class ExpressiveButton extends StatefulWidget {
  const ExpressiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = ExpressiveTone.filled,
    this.expanded = false,
    this.autofocus = false,
    this.height = 58,
    this.focusNode,
    this.hint,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ExpressiveTone tone;
  final bool expanded;
  final bool autofocus;
  final double height;
  final FocusNode? focusNode;
  final String? hint;

  @override
  State<ExpressiveButton> createState() => _ExpressiveButtonState();
}

class _ExpressiveButtonState extends State<ExpressiveButton> {
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    final material = style.isMaterial;
    final enabled = widget.onPressed != null;
    final (bg, fg, border) = switch (widget.tone) {
      ExpressiveTone.filled => (
        material
            ? [
                scheme.primary,
                Color.lerp(scheme.primary, scheme.secondary, 0.45)!,
              ]
            : [
                scheme.primary.withValues(alpha: 0.94),
                Color.lerp(scheme.primary, scheme.primaryContainer, 0.55)!,
              ],
        scheme.onPrimary,
        material ? Colors.transparent : Colors.white.withValues(alpha: 0.22),
      ),
      ExpressiveTone.tonal => (
        [scheme.surfaceContainerHigh, scheme.surfaceContainerHighest],
        scheme.onSurface,
        style.chipBorder,
      ),
      ExpressiveTone.glass => (
        material
            ? [
                scheme.surfaceContainerHigh.withValues(alpha: 0.72),
                scheme.surfaceContainer.withValues(alpha: 0.45),
              ]
            : [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.08),
              ],
        scheme.onSurface,
        material ? style.chipBorder : Colors.white.withValues(alpha: 0.24),
      ),
      ExpressiveTone.danger => (
        [
          scheme.errorContainer,
          Color.lerp(scheme.errorContainer, scheme.error, 0.18)!,
        ],
        scheme.onErrorContainer,
        scheme.error.withValues(alpha: 0.35),
      ),
    };

    final scale = !enabled
        ? 1.0
        : _pressed
        ? style.pressScale
        : (_focused ? (material ? 1.025 : 1.008) : 1.0);
    final content = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 21, color: fg),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg),
          ),
        ),
      ],
    );

    final button = AnimatedScale(
      scale: scale,
      // Press feedback stays snappy; the release gets a long enough runway for
      // the expressive spring to visibly overshoot on the material language.
      duration: _pressed && !material
          ? Motion.fast
          : (material ? Motion.release : Motion.fast),
      curve: material ? Motion.springy : Motion.standard,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.emphasizedDecelerate,
        height: widget.height,
        width: widget.expanded ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(style.buttonRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bg,
          ),
          border: Border.all(
            color: _focused ? scheme.secondary : border,
            width: _focused ? 2 : 1,
          ),
          boxShadow: material
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(
                      alpha: _focused ? 0.42 : (_hovered ? 0.24 : 0.16),
                    ),
                    blurRadius: _focused ? 34 : 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _focused ? 0.28 : 0.20,
                    ),
                    blurRadius: _focused ? 28 : 18,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: content,
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.hint ?? widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            canRequestFocus: enabled,
            onTap: widget.onPressed,
            onFocusChange: (value) => setState(() => _focused = value),
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: enabled
                ? () => setState(() => _pressed = false)
                : null,
            splashColor: fg.withValues(alpha: 0.16),
            highlightColor: Colors.transparent,
            customBorder: const StadiumBorder(),
            child: button,
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 48,
    this.autofocus = false,
    this.tone,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool autofocus;
  final Color? tone;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    final tone = widget.tone;
    final icon = Icon(
      widget.icon,
      size: widget.size * 0.44,
      color: tone ?? scheme.onSurface,
    );

    Widget result;
    if (style.isLiquid) {
      result = Glass(
        borderRadius: widget.size / 2,
        blur: 20,
        padding: EdgeInsets.zero,
        onTap: widget.onPressed,
        tint: tone,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(child: icon),
        ),
      );
    } else {
      final content = AnimatedContainer(
        duration: Motion.fast,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHigh,
          border: Border.all(
            color: _focused ? scheme.primary : style.chipBorder,
            width: _focused ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _focused ? 0.28 : 0.16),
              blurRadius: _focused ? 24 : 16,
              offset: const Offset(0, 8),
            ),
            if (_focused)
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.38),
                blurRadius: 22,
              ),
          ],
        ),
        child: Center(child: icon),
      );

      result = Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          autofocus: widget.autofocus,
          onTap: widget.onPressed,
          onFocusChange: (value) => setState(() => _focused = value),
          child: content,
        ),
      );
    }

    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return result;
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: style.isMaterial ? 1.6 : 1.25,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style, this.colors});

  final String text;
  final TextStyle? style;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appStyle = AppStyle.of(context);
    final palette =
        colors ??
        (appStyle.isMaterial
            ? [scheme.onSurface, scheme.primary, scheme.secondary]
            : [
                scheme.onSurface,
                Color.lerp(scheme.onSurface, scheme.primary, 0.55)!,
                scheme.onSurfaceVariant,
              ]);
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: palette,
        stops: const [0, 0.55, 1],
      ).createShader(bounds),
      child: Text(text, style: style),
    );
  }
}

class AvatarBubble extends StatelessWidget {
  const AvatarBubble({
    super.key,
    required this.member,
    this.size = 48,
    this.showStatus = true,
    this.glow = false,
  });

  final Member member;
  final double size;
  final bool showStatus;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(member.colorHex);
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: [
                  Color.lerp(
                    color,
                    Colors.white,
                    0.35,
                  )!.withValues(alpha: 0.95),
                  color.withValues(alpha: 0.75),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glow ? 0.55 : 0.28),
                  blurRadius: glow ? 26 : 14,
                  spreadRadius: glow ? 3 : 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              member.avatar,
              style: TextStyle(fontSize: size * 0.46, height: 1),
            ),
          ),
          if (showStatus)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: member.online ? style.live : scheme.outline,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.color, this.size = 8});

  final Color? color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
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
        final t = _controller.value;
        return SizedBox.square(
          dimension: widget.size * 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t) * 0.5,
                child: Container(
                  width: widget.size * (1 + t * 2),
                  height: widget.size * (1 + t * 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    this.stroke = 8,
    this.child,
    this.colors,
    this.trackColor,
  });

  final double value;
  final double size;
  final double stroke;
  final Widget? child;
  final List<Color>? colors;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    final ringColors =
        colors ??
        (style.isMaterial
            ? [scheme.secondary, scheme.primary, scheme.tertiary]
            : [
                style.live,
                Color.lerp(scheme.onSurface, scheme.primary, 0.45)!,
                scheme.onSurfaceVariant,
              ]);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: Motion.slow,
      curve: Motion.emphasizedDecelerate,
      builder: (context, animated, _) {
        return SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: animated,
              stroke: stroke,
              colors: ringColors,
              track:
                  trackColor ??
                  scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.colors,
    required this.track,
  });

  final double value;
  final double stroke;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0.001) return;
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: math.pi * 1.5,
      colors: [...colors, colors.first],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = shader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint,
    );
    final crisp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = shader;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      crisp,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.stroke != stroke || old.colors != colors;
}

class ToggleOption<T> {
  const ToggleOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class TogglePill<T> extends StatelessWidget {
  const TogglePill({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.expanded = true,
  });

  final List<ToggleOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: style.chipFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.chipBorder),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final option in options)
            Expanded(
              flex: expanded ? 1 : 0,
              child: _ToggleItem<T>(
                option: option,
                selected: option.value == value,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleItem<T> extends StatefulWidget {
  const _ToggleItem({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ToggleOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ToggleItem<T>> createState() => _ToggleItemState<T>();
}

class _ToggleItemState<T> extends State<_ToggleItem<T>> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (value) => setState(() => _focused = value),
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.emphasizedDecelerate,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: widget.selected ? scheme.primary : Colors.transparent,
            border: Border.all(
              color: _focused ? scheme.secondary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.option.icon != null) ...[
                Icon(
                  widget.option.icon,
                  size: 16,
                  color: widget.selected
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: widget.selected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1 · 2 · 3" TV remote hint row.
class RemoteHint extends StatelessWidget {
  const RemoteHint({super.key, required this.labels, this.compact = false});

  final List<String> labels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final textStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 11,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: style.chipFill,
              borderRadius: BorderRadius.circular(style.isMaterial ? 10 : 8),
              border: Border.all(color: style.chipBorder),
            ),
            child: Text(label, style: textStyle),
          ),
      ],
    );
  }
}

/// A softly animated keycap used for invite codes.
class Keycap extends StatelessWidget {
  const Keycap({
    super.key,
    required this.character,
    this.size = 44,
    this.highlight = false,
  });

  final String character;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    final material = style.isMaterial;
    final fg = highlight ? scheme.onPrimary : scheme.onSurface;
    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.emphasizedDecelerate,
      width: size,
      height: size * 1.2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          material ? size * 0.36 : size * 0.28,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highlight
              ? [
                  scheme.primary,
                  Color.lerp(scheme.primary, scheme.secondary, 0.4)!,
                ]
              : material
              ? [scheme.surfaceContainerHighest, scheme.surfaceContainerHigh]
              : [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.06),
                ],
        ),
        border: Border.all(
          color: highlight ? Colors.transparent : style.chipBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? scheme.primary.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.18),
            blurRadius: highlight ? 22 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        character,
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

/// Stat with a big number and tiny label. The HUD's building block.
class StatValue extends StatelessWidget {
  const StatValue({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.accent,
    this.sub,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? accent;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1.4),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: accent ?? scheme.onSurface,
                    fontSize: 38,
                  ),
                ),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 6),
              Text(
                unit!,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
        if (sub != null)
          Text(
            sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

String memberFirstName(Member member) =>
    member.name.split(RegExp(r'\s+')).first;

String memberInitials(Member member) => initialsFor(member.name);
