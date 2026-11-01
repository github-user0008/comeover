import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../models/member.dart';
import '../aurora_background.dart';
import '../brand.dart';
import '../expressive.dart';
import '../glass.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  JoinPreview? _preview;
  String? _previewError;
  bool _checking = false;
  bool _joining = false;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final pending = AppScope.of(context).pendingJoinCode;
    if (pending.isNotEmpty) {
      _controller.text = pending.toUpperCase();
      _onChanged(pending);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _code => _controller.text.trim().toUpperCase();

  void _onChanged(String value) {
    final code = value.trim().toUpperCase();
    setState(() {
      _preview = null;
      _previewError = null;
    });
    _debounce?.cancel();
    if (code.length < 6) return;
    _debounce = Timer(const Duration(milliseconds: 350), () => _peek(code));
  }

  Future<void> _peek(String code) async {
    final app = AppScope.of(context);
    setState(() => _checking = true);
    final preview = await app.peek(code);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _preview = preview;
      _previewError = preview == null
          ? (app.errorMessage ?? 'No room found')
          : null;
    });
    if (preview == null) app.clearError();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    final match = RegExp(r'[A-Za-z0-9]{6}').firstMatch(text);
    final code = (match?.group(0) ?? text).toUpperCase();
    _controller.text = code;
    _controller.selection = TextSelection.collapsed(offset: code.length);
    _onChanged(code);
  }

  Future<void> _join() async {
    if (_joining) return;
    final app = AppScope.of(context);
    setState(() => _joining = true);
    await app.joinRoom(_code, device: DeviceScope.of(context).kind);
    if (mounted) setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final device = DeviceScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final canJoin = _code.length >= 6 && !app.busy && !_joining;

    return PageFrame(
      maxWidth: 560,
      padding: EdgeInsets.symmetric(
        horizontal: device.isTv ? 44 : 18,
        vertical: 14,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => app.goHome(),
              ),
              const SizedBox(width: 12),
              const Wordmark(compact: true),
            ],
          ),
          const SizedBox(height: 20),
          Glass(
            borderRadius: 34,
            padding: EdgeInsets.all(device.isTv ? 32 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Join a room'),
                const SizedBox(height: 10),
                Text(
                  'Type the code',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  "It's the six characters your host sent. Case doesn't matter.",
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: !device.isTv,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.visiblePassword,
                  maxLength: 6,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    letterSpacing: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) =>
                          newValue.copyWith(text: newValue.text.toUpperCase()),
                    ),
                  ],
                  onChanged: _onChanged,
                  onSubmitted: (_) {
                    if (canJoin) _join();
                  },
                  decoration: const InputDecoration(
                    hintText: 'ABC123',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 22,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste_rounded, size: 16),
                      label: const Text('Paste'),
                    ),
                    const Spacer(),
                    if (_checking)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: _PreviewPanel(preview: _preview, error: _previewError),
                ),
                const SizedBox(height: 20),
                ExpressiveButton(
                  label: _joining ? 'Joining…' : 'Join room',
                  icon: Icons.login_rounded,
                  expanded: true,
                  height: device.isTv ? 64 : 58,
                  autofocus: _code.length == 6,
                  onPressed: canJoin ? _join : null,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'We ask for your location once you join so the host can see your ETA. '
                        'You can join without it and share later.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (device.isTv) ...[
            const SizedBox(height: 16),
            const Center(
              child: RemoteHint(
                labels: ['Type with the on-screen keyboard', 'OK to join'],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.preview, required this.error});

  final JoinPreview? preview;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (preview == null && error == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final appStyle = AppStyle.of(context);
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded, size: 18, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No room with that code. Check the digits and try again.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      );
    }
    final previewData = preview!;
    Member? host;
    for (final member in previewData.members) {
      if (member.isHost) {
        host = member;
        break;
      }
    }
    host ??= previewData.members.isEmpty ? null : previewData.members.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: appStyle.live.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: appStyle.live.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Text(
              host?.avatar ?? '🏠',
              style: const TextStyle(fontSize: 28, height: 1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    host == null ? "Someone's room" : '${host.name} is waiting',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${preview!.members.length} ${plural(preview!.members.length, 'person', 'people')} in the room · '
                    'code ${preview!.room.code}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle_rounded, color: appStyle.live, size: 20),
          ],
        ),
      ),
    );
  }
}
