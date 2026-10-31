import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../models/member.dart';
import '../../state/app_controller.dart';
import '../aurora_background.dart';
import '../brand.dart';
import '../expressive.dart';
import '../glass.dart';

class EndedScreen extends StatelessWidget {
  const EndedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final device = DeviceScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final room = app.room;
    final members = app.members;
    final duration = room == null
        ? Duration.zero
        : DateTime.now().difference(room.createdAt);
    final together = duration.isNegative ? Duration.zero : duration;

    return PageFrame(
      maxWidth: 760,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: device.isTv ? 44 : 18, vertical: 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Wordmark(tagline: true),
            const SizedBox(height: 24),
            Glass(
              borderRadius: 40,
              padding: EdgeInsets.all(device.isTv ? 38 : 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 52, animated: false),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'That’s a wrap',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              app.endedReason ?? 'The room is closed.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  if (room != null)
                    Row(
                      children: [
                        Expanded(
                          child: _Summary(
                            label: 'Room',
                            value: room.code,
                            icon: Icons.tag_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Summary(
                            label: 'Together for',
                            value: together.inMinutes < 1
                                ? 'under a minute'
                                : formatDuration(together, precise: false),
                            icon: Icons.schedule_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Summary(
                            label: 'People',
                            value: '${members.length}',
                            icon: Icons.group_rounded,
                          ),
                        ),
                      ],
                    ),
                  if (members.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const SectionLabel('Who was here'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final member in _ordered(app))
                          _PersonChip(member: member),
                      ],
                    ),
                  ],
                  const SizedBox(height: 26),
                  Text(
                    'Location sharing has stopped. The relay forgets this room when the invite expires — '
                    'nothing is written to a database.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ExpressiveButton(
                          label: 'Back home',
                          icon: Icons.home_rounded,
                          expanded: true,
                          height: device.isTv ? 62 : 56,
                          autofocus: true,
                          onPressed: app.goHome,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ExpressiveButton(
                          label: 'New room',
                          icon: Icons.add_location_alt_rounded,
                          tone: ExpressiveTone.tonal,
                          expanded: true,
                          height: device.isTv ? 62 : 56,
                          onPressed: app.goHome,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (device.isTv) ...[
              const SizedBox(height: 16),
              const Center(child: RemoteHint(labels: ['OK select', '← back home'])),
            ],
          ],
        ),
      ),
    );
  }

  List<Member> _ordered(AppController app) {
    final list = [...app.members];
    list.sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 1),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                ),
          ),
        ],
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = colorFromHex(member.colorHex);
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 13, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarBubble(member: member, size: 30, showStatus: false),
          const SizedBox(width: 8),
          Text(member.name, style: Theme.of(context).textTheme.labelMedium),
          if (member.isHost) ...[
            const SizedBox(width: 5),
            Icon(Icons.key_rounded, size: 12, color: scheme.onSurfaceVariant),
          ],
        ],
      ),
    );
  }
}
