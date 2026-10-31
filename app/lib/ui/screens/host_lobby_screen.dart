import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../core/device.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/app_controller.dart';
import '../aurora_background.dart';
import '../brand.dart';
import '../expressive.dart';
import '../glass.dart';

class HostLobbyScreen extends StatefulWidget {
  const HostLobbyScreen({super.key});

  @override
  State<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends State<HostLobbyScreen> {
  Timer? _clock;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _copy(BuildContext context, String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    AppScope.of(context).showNotice(message);
  }

  Future<void> _share(BuildContext context) async {
    final app = AppScope.of(context);
    final text = 'Come over — join me on ComeOver.\n\nCode: ${app.roomCode}\n${app.inviteLink}';
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: 'Come over'));
    } catch (_) {
      if (!context.mounted) return;
      await _copy(context, text, 'Invite copied to clipboard');
    }
  }

  Future<void> _closeRoom(BuildContext context) async {
    final app = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close the room?'),
        content: const Text('Everyone loses the live view immediately and the invite stops working.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it open')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Close room')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    setState(() => _ending = true);
    await app.endRoom();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final device = DeviceScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final room = app.room;
    if (room == null) return const SizedBox.shrink();
    final expiresIn = room.expiresAt.difference(DateTime.now());
    final expiry = expiresIn.isNegative ? 'expired' : formatDuration(expiresIn, precise: false);

    return PageFrame(
      maxWidth: 1160,
      padding: EdgeInsets.symmetric(
        horizontal: device.isTv ? 44 : 18,
        vertical: device.isTv ? 30 : 14,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Wordmark(compact: device.isCompact),
                const Spacer(),
                if (!device.isCompact)
                  FrostChip(
                    label: 'Expires in $expiry',
                    icon: const Icon(Icons.schedule_rounded, size: 15),
                    compact: true,
                  ),
                const SizedBox(width: 10),
                GlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close room',
                  onPressed: _ending ? null : () => _closeRoom(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (device.isExpanded)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _InviteCard(app: app, device: device, onShare: _share, onCopy: _copy)),
                  const SizedBox(width: 22),
                  Expanded(flex: 4, child: _WaitingCard(app: app, device: device, expiry: expiry)),
                ],
              )
            else ...[
              _InviteCard(app: app, device: device, onShare: _share, onCopy: _copy),
              const SizedBox(height: 16),
              _WaitingCard(app: app, device: device, expiry: expiry),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No account needed. Your guest sees only this room while it is open.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.app,
    required this.device,
    required this.onShare,
    required this.onCopy,
  });

  final AppController app;
  final DeviceProfile device;
  final Future<void> Function(BuildContext) onShare;
  final Future<void> Function(BuildContext, String, String) onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final code = app.roomCode;
    final wideEnoughForQr = MediaQuery.of(context).size.width > 420;

    return Glass(
      borderRadius: 36,
      padding: EdgeInsets.all(device.isTv ? 32 : 24),
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Invite ready'),
            const SizedBox(height: 12),
            Text(
              'Send them the code.',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: device.isTv ? 34 : 28),
            ),
            const SizedBox(height: 6),
            Text(
              'They type it in, share their location, and you both see the ETA.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            if (wideEnoughForQr)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _CodeBlock(code: code, onCopy: onCopy)),
                  const SizedBox(width: 18),
                  _Qr(link: app.inviteLink, size: device.isTv ? 168 : 132),
                ],
              )
            else ...[
              _CodeBlock(code: code, onCopy: onCopy),
              const SizedBox(height: 16),
              Center(child: _Qr(link: app.inviteLink, size: 152)),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ExpressiveButton(
                    label: 'Share invite',
                    icon: Icons.ios_share_rounded,
                    expanded: true,
                    autofocus: true,
                    height: device.isTv ? 62 : 56,
                    onPressed: () => onShare(context),
                  ),
                ),
                const SizedBox(width: 10),
                GlassIconButton(
                  icon: Icons.copy_rounded,
                  tooltip: 'Copy link',
                  size: device.isTv ? 56 : 52,
                  onPressed: () => onCopy(context, app.inviteLink, 'Invite link copied'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.link_rounded, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    app.inviteLink,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.2,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.onCopy});

  final String code;
  final Future<void> Function(BuildContext, String, String) onCopy;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width < 380 ? 40.0 : 46.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < code.length; i++) ...[
              Keycap(character: code[i], size: size),
              if (i < code.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Tap the code to copy',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => onCopy(context, code, 'Code $code copied'),
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text('Copy code $code'),
        ),
      ],
    );
  }
}

class _Qr extends StatelessWidget {
  const _Qr({required this.link, required this.size});

  final String link;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Palette.violet.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: QrImageView(
        data: link,
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        padding: EdgeInsets.zero,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Palette.ink),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Palette.ink,
        ),
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.app, required this.device, required this.expiry});

  final AppController app;
  final DeviceProfile device;
  final String expiry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = app.profile.name.isEmpty ? 'your guest' : 'them';
    return Glass(
      borderRadius: 36,
      padding: EdgeInsets.all(device.isTv ? 30 : 22),
      child: Column(
        children: [
          RadarSweep(
            size: device.isTv ? 280 : 220,
            child: Container(
              width: device.isTv ? 88 : 72,
              height: device.isTv ? 88 : 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.secondary.withValues(alpha: 0.8)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                boxShadow: [
                  BoxShadow(color: scheme.primary.withValues(alpha: 0.5), blurRadius: 30),
                ],
              ),
              child: Text(app.profile.avatar, style: TextStyle(fontSize: device.isTv ? 42 : 34, height: 1)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const WaitingDots(),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Waiting for $name to join…',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Keep this screen open. You will jump straight into the live view the moment they join.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => app.startDemoTraveller(),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Try a demo'),
                ),
              ),
            ],
          ),
          if (app.locationUnavailable) ...[
            const SizedBox(height: 12),
            Text(
              'No location yet — your guest will still appear, but distance needs your point.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Palette.lemon),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Invite expires in $expiry',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
