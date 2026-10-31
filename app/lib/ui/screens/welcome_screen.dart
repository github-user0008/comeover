import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../aurora_background.dart';
import '../avatar_picker.dart';
import '../brand.dart';
import '../expressive.dart';
import '../glass.dart';
import '../route_illustration.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _avatar = '🦊';
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final app = AppScope.of(context);
    final ok = await app.completeWelcome(_controller.text, _avatar);
    if (!ok && mounted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tell people what to call you.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final device = DeviceScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxWidth = device.isTv ? 720.0 : device.isTablet ? 620.0 : 520.0;

    return PageFrame(
      padding: device.isTv
          ? const EdgeInsets.symmetric(horizontal: 48, vertical: 32)
          : const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      maxWidth: maxWidth,
      child: Column(
        children: [
          const Spacer(),
          RiseIn(
            child: Column(
              children: [
                const Wordmark(tagline: true),
                const SizedBox(height: 10),
                Text(
                  'Invite someone. Watch the distance shrink.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          RiseIn(
            delay: const Duration(milliseconds: 120),
            child: const RouteIllustration(leftEmoji: '🦊', rightEmoji: '🐼'),
          ),
          const SizedBox(height: 26),
          RiseIn(
            delay: const Duration(milliseconds: 200),
            child: Glass(
              borderRadius: 34,
              padding: EdgeInsets.all(device.isTv ? 34 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Who are you'),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.done,
                    autofocus: !device.isTv,
                    maxLength: 24,
                    onSubmitted: (_) => _continue(),
                    decoration: const InputDecoration(
                      hintText: 'Display name',
                      counterText: '',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionLabel('Pick an avatar'),
                  const SizedBox(height: 12),
                  AvatarPicker(
                    selected: _avatar,
                    onSelected: (value) => setState(() => _avatar = value),
                    size: device.isTv ? 60 : 52,
                  ),
                  const SizedBox(height: 26),
                  ExpressiveButton(
                    label: app.busy || _submitting ? 'Getting started…' : 'Let me in',
                    icon: Icons.arrow_forward_rounded,
                    expanded: true,
                    height: device.isTv ? 64 : 58,
                    onPressed: (app.busy || _submitting) ? null : _continue,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          RiseIn(
            delay: const Duration(milliseconds: 320),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Works on FireOS TV, Android TV, Android & iOS',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
