import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../app.dart';
import '../../core/device.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../data/realtime.dart';
import '../../state/app_controller.dart';
import '../aurora_background.dart';
import '../brand.dart';
import '../expressive.dart';
import '../glass.dart';
import '../map_picker_screen.dart';
import '../route_illustration.dart';
import '../settings_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final device = DeviceScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return PageFrame(
      maxWidth: 1240,
      padding: EdgeInsets.symmetric(
        horizontal: device.isTv ? 44 : 20,
        vertical: device.isTv ? 30 : 14,
      ),
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(app: app, device: device),
            const SizedBox(height: 26),
            if (device.isExpanded)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _Hero(app: app, device: device)),
                  const SizedBox(width: 24),
                  Expanded(flex: 5, child: _Actions(app: app, device: device)),
                ],
              )
            else ...[
              _Hero(app: app, device: device),
              const SizedBox(height: 18),
              _Actions(app: app, device: device),
            ],
            const SizedBox(height: 26),
            _HowItWorks(device: device),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location only moves while a room is open. Kill the room and sharing stops instantly.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (device.isTv) ...[
              const SizedBox(height: 18),
              const Center(
                child: RemoteHint(labels: ['◀ ▶ ▲ ▼ move', 'OK select', '← back']),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.app, required this.device});

  final AppController app;
  final DeviceProfile device;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Wordmark(compact: device.isCompact),
        const Spacer(),
        if (!device.isCompact) ...[
          _RelayPill(app: app),
          const SizedBox(width: 12),
        ],
        _ProfileChip(app: app),
      ],
    );
  }
}

class _RelayPill extends StatelessWidget {
  const _RelayPill({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = app.relayStatus.isLive;
    final color = switch (app.relayStatus) {
      RelayStatus.connected => Palette.mint,
      RelayStatus.connecting || RelayStatus.reconnecting => Palette.lemon,
      _ => Palette.peach,
    };
    final host = Uri.tryParse(app.config.serverUrl)?.host ?? app.config.serverUrl;
    return Tooltip(
      message: 'Realtime relay: ${app.config.serverUrl}',
      child: Glass(
        borderRadius: 999,
        blur: 10,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () => openSettings(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              live ? 'Relay live · $host' : app.relayStatus.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Glass(
      borderRadius: 999,
      blur: 10,
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      onTap: () => openSettings(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [scheme.primary.withValues(alpha: 0.8), scheme.secondary.withValues(alpha: 0.5)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: Text(app.profile.avatar, style: const TextStyle(fontSize: 20, height: 1)),
          ),
          const SizedBox(width: 10),
          Text(
            app.profile.name.isEmpty ? 'You' : app.profile.name,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.app, required this.device});

  final AppController app;
  final DeviceProfile device;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Glass(
      borderRadius: 38,
      padding: EdgeInsets.all(device.isTv ? 34 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LiveDot(),
              const SizedBox(width: 4),
              Text(
                'REAL-TIME ARRIVALS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Palette.mint,
                      letterSpacing: 1.8,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GradientText(
            'Invite someone\nover.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: device.isTv ? 50 : 42,
                  height: 1.0,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            'Send a code. They join in a tap. You watch their live distance, ETA and '
            'second-by-second countdown until they knock.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 6),
          RouteIllustration(
            height: device.isTv ? 150 : 124,
            leftEmoji: app.profile.avatar,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _MiniChip(icon: Icons.straighten_rounded, label: 'Live distance'),
              _MiniChip(icon: Icons.timer_outlined, label: 'ETA + countdown'),
              _MiniChip(icon: Icons.tv_rounded, label: 'TV friendly'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.app, required this.device});

  final AppController app;
  final DeviceProfile device;

  Future<void> _start(BuildContext context, {bool demo = false}) async {
    final kind = device.kind;
    final navigator = Navigator.of(context);

    Future<LatLng?> pickPoint() {
      return navigator.push<LatLng>(
        MaterialPageRoute(
          builder: (_) => MapPickerScreen(
            initial: app.myPoint ?? const LatLng(12.9716, 77.5946),
            title: demo ? 'Where should they arrive?' : 'Set your meeting point',
            confirmLabel: demo ? 'Start demo' : 'Use this point',
          ),
        ),
      );
    }

    if (kind == DeviceClass.tv) {
      final point = await pickPoint();
      if (point == null || !context.mounted) return;
      await app.createRoom(device: kind, at: point, startDemo: demo);
      return;
    }

    final ok = await app.createRoom(device: kind, startDemo: demo);
    if (!ok && app.locationUnavailable && context.mounted) {
      final point = await pickPoint();
      if (point == null || !context.mounted) return;
      await app.createRoom(device: kind, at: point, startDemo: demo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Glass(
      borderRadius: 38,
      padding: EdgeInsets.all(device.isTv ? 30 : 22),
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel(demoTitle(app))),
                Icon(Icons.bolt_rounded, size: 18, color: scheme.secondary),
              ],
            ),
            const SizedBox(height: 16),
            ExpressiveButton(
              label: app.busy ? 'Opening…' : 'Start a room',
              icon: Icons.add_location_alt_rounded,
              expanded: true,
              height: device.isTv ? 66 : 60,
              autofocus: true,
              onPressed: app.busy ? null : () => _start(context),
            ),
            const SizedBox(height: 12),
            ExpressiveButton(
              label: 'Join with a code',
              icon: Icons.qr_code_scanner_rounded,
              tone: ExpressiveTone.tonal,
              expanded: true,
              height: device.isTv ? 62 : 56,
              onPressed: app.busy ? null : () => app.openJoin(),
            ),
            const SizedBox(height: 12),
            ExpressiveButton(
              label: 'Watch a live demo',
              icon: Icons.auto_awesome_rounded,
              tone: ExpressiveTone.glass,
              expanded: true,
              height: device.isTv ? 62 : 56,
              onPressed: app.busy ? null : () => _start(context, demo: true),
            ),
            const SizedBox(height: 18),
            Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            if (app.prefs.recentCodes.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(child: SectionLabel('Recent rooms')),
                  if (app.prefs.recentCodes.isNotEmpty)
                    GestureDetector(
                      onTap: () => app.prefs.clearRecent(),
                      child: Text(
                        'Clear',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final code in app.prefs.recentCodes)
                    _RecentChip(code: code, onTap: () => app.openJoin(code)),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _SetupRow(
              icon: Icons.public_rounded,
              label: 'Relay',
              value: Uri.tryParse(app.config.serverUrl)?.authority ?? app.config.serverUrl,
              onTap: () => openSettings(context),
            ),
            const SizedBox(height: 8),
            _SetupRow(
              icon: Icons.near_me_outlined,
              label: 'My sharing',
              value: app.locationUnavailable ? 'Needs location' : 'Ready',
              onTap: () => openSettings(context),
            ),
          ],
        ),
      ),
    );
  }

  String demoTitle(AppController app) => app.profile.name.isEmpty ? 'Start here' : 'Start here, ${app.profile.name.split(' ').first}';
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.code, required this.onTap});

  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: const Icon(Icons.history_rounded, size: 16),
      label: Text(code),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.4),
      shape: const StadiumBorder(),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
    );
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.device});

  final DeviceProfile device;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.qr_code_2_rounded, 'Invite', 'Share a 6-character code or link.'),
      (Icons.group_add_rounded, 'They join', 'One tap. No accounts, no sign-up.'),
      (Icons.near_me_rounded, 'Watch them arrive', 'Distance, ETA and countdown, live.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('How it works'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < steps.length; i++)
              SizedBox(
                width: device.isExpanded ? (device.contentWidth - 24) / 3 : double.infinity,
                child: RiseIn(
                  delay: Duration(milliseconds: 40 * i),
                  child: Glass(
                    borderRadius: 26,
                    blur: 12,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Icon(steps[i].$1, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${i + 1}. ${steps[i].$2}', style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                steps[i].$3,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
