import 'package:flutter/material.dart';

import '../core/motion.dart';

const profileAvatars = ['🦊', '🐼', '🐙', '🦄', '🐸', '🦁', '🐧', '🦉'];

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.size = 52,
    this.spacing = 10,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final avatar in profileAvatars)
          _AvatarChoice(
            avatar: avatar,
            selected: avatar == selected,
            size: size,
            onTap: () => onSelected(avatar),
            scheme: scheme,
          ),
      ],
    );
  }
}

class _AvatarChoice extends StatefulWidget {
  const _AvatarChoice({
    required this.avatar,
    required this.selected,
    required this.size,
    required this.onTap,
    required this.scheme,
  });

  final String avatar;
  final bool selected;
  final double size;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  State<_AvatarChoice> createState() => _AvatarChoiceState();
}

class _AvatarChoiceState extends State<_AvatarChoice> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onTap,
        onFocusChange: (value) => setState(() => _focused = value),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.emphasizedDecelerate,
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.selected
                ? widget.scheme.primary.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: widget.selected
                  ? widget.scheme.primary
                  : (_focused ? widget.scheme.secondary : Colors.white.withValues(alpha: 0.12)),
              width: widget.selected || _focused ? 2 : 1,
            ),
            boxShadow: [
              if (widget.selected)
                BoxShadow(
                  color: widget.scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                ),
            ],
          ),
          child: Text(widget.avatar, style: TextStyle(fontSize: widget.size * 0.46, height: 1)),
        ),
      ),
    );
  }
}
