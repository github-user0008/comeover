import 'package:flutter/material.dart';

import '../app.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/realtime.dart';
import 'avatar_picker.dart';
import 'expressive.dart';
import 'glass.dart';

Future<void> openSettings(BuildContext context) async {
  final device = DeviceScope.of(context);
  if (device.isCompact) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const FractionallySizedBox(
          heightFactor: 0.94,
          child: SettingsSheet(),
        ),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 900),
          child: const SettingsSheet(),
        ),
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _serverController;
  late String _avatar;
  bool _savingName = false;
  bool _testing = false;
  bool? _relayOk;
  String? _serverError;

  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final app = AppScope.of(context);
    _nameController = TextEditingController(text: app.profile.name);
    _serverController = TextEditingController(text: app.serverOverride ?? app.config.serverUrl);
    _avatar = app.profile.avatar;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final app = AppScope.of(context);
    setState(() => _savingName = true);
    await app.updateProfile(name: _nameController.text, avatar: _avatar);
    if (!mounted) return;
    setState(() => _savingName = false);
    app.showNotice('Profile updated');
  }

  Future<void> _testRelay() async {
    final app = AppScope.of(context);
    setState(() {
      _testing = true;
      _relayOk = null;
      _serverError = null;
    });
    final ok = await app.setServerOverride(_serverController.text);
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _serverError = app.errorMessage ?? 'That address looks wrong.';
      });
      return;
    }
    final healthy = await app.checkRelay();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _relayOk = healthy;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final device = DeviceScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Glass(
      borderRadius: device.isCompact ? 34 : 32,
      blur: 24,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
                      Text(
                        'Tune the room, the look, the relay.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                GlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(
                    context,
                    title: 'You',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.primary.withValues(alpha: 0.9),
                                    scheme.secondary.withValues(alpha: 0.55),
                                  ],
                                ),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                              ),
                              child: Text(_avatar, style: const TextStyle(fontSize: 30, height: 1)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                maxLength: 24,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  hintText: 'Display name',
                                  counterText: '',
                                ),
                                onSubmitted: (_) => _saveProfile(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ExpressiveButton(
                              label: _savingName ? '…' : 'Save',
                              height: 52,
                              onPressed: _savingName ? null : _saveProfile,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AvatarPicker(
                          selected: _avatar,
                          onSelected: (value) => setState(() => _avatar = value),
                          size: 44,
                          spacing: 8,
                        ),
                      ],
                    ),
                  ),
                  _section(
                    context,
                    title: 'Distance units',
                    child: TogglePill<UnitSystem>(
                      value: app.units,
                      onChanged: app.setUnits,
                      options: const [
                        ToggleOption(value: UnitSystem.metric, label: 'Metric · km', icon: Icons.straighten_rounded),
                        ToggleOption(value: UnitSystem.imperial, label: 'Imperial · mi', icon: Icons.square_foot_rounded),
                      ],
                    ),
                  ),
                  _section(
                    context,
                    title: 'Appearance',
                    child: Column(
                      children: [
                        TogglePill<ThemeMode>(
                          value: app.themeMode,
                          onChanged: app.setThemeMode,
                          options: const [
                            ToggleOption(value: ThemeMode.dark, label: 'Night', icon: Icons.dark_mode_outlined),
                            ToggleOption(value: ThemeMode.light, label: 'Day', icon: Icons.light_mode_outlined),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _ToggleRow(
                          title: 'Liquid glass',
                          subtitle: 'Frosted blur and rim light. Turn off on older TVs for smoothness.',
                          value: !app.reduceGlass,
                          onChanged: (value) => app.setReduceGlass(!value),
                        ),
                        _ToggleRow(
                          title: 'Expressive motion',
                          subtitle: 'Springy presses, drifting aurora and countdown animations.',
                          value: !app.reduceMotion,
                          onChanged: (value) => app.setReduceMotion(!value),
                        ),
                        const SizedBox(height: 6),
                        _LabeledRow(
                          title: 'TV layout',
                          subtitle: 'Bigger buttons, focus rings and overscan padding.',
                          child: TogglePill<String>(
                            value: app.forceTv == null ? 'auto' : (app.forceTv! ? 'on' : 'off'),
                            expanded: false,
                            onChanged: (value) => app.setForceTv(value == 'auto' ? null : value == 'on'),
                            options: const [
                              ToggleOption(value: 'auto', label: 'Auto'),
                              ToggleOption(value: 'on', label: 'On'),
                              ToggleOption(value: 'off', label: 'Off'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (app.room != null)
                    _section(
                      context,
                      title: 'This room',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LabeledRow(
                            title: 'Hide exact distance',
                            subtitle: app.isHost
                                ? 'Everyone sees a ~110 m area instead of a precise point.'
                                : 'Blur your own position before it leaves this device. The host controls room-wide precision.',
                            child: Switch.adaptive(
                              value: app.isHost ? app.room!.settings.isApproximate : app.approximateLocal,
                              onChanged: (value) => app.setPrecision(approximate: value),
                            ),
                          ),
                          _LabeledRow(
                            title: 'Pause my sharing',
                            subtitle: 'The room stays open; your dot freezes until you turn it back on.',
                            child: Switch.adaptive(
                              value: app.sharingPaused,
                              onChanged: app.setSharingPaused,
                            ),
                          ),
                          if (app.isHost) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _LabeledRow(
                                    title: 'Arrival radius',
                                    subtitle: 'Turns the countdown into a celebration inside this circle.',
                                    child: Text(
                                      formatDistance(app.room!.settings.arrivalRadius, app.units),
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: app.room!.settings.arrivalRadius.clamp(15, 200),
                              min: 15,
                              max: 200,
                              divisions: 37,
                              label: formatDistance(app.room!.settings.arrivalRadius, app.units),
                              onChanged: app.setArrivalRadius,
                            ),
                          ],
                        ],
                      ),
                    ),
                  _section(
                    context,
                    title: 'Relay',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _serverController,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            hintText: 'http://192.168.1.20:8787',
                            prefixIcon: Icon(Icons.dns_outlined),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Both devices (and the TV) must reach this address. On a LAN, use your '
                          "computer's IP, not localhost.",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if (_serverError != null) ...[
                          const SizedBox(height: 8),
                          Text(_serverError!, style: TextStyle(color: scheme.error, fontSize: 12)),
                        ],
                        if (_relayOk != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _relayOk! ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                size: 16,
                                color: _relayOk! ? Palette.mint : scheme.error,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _relayOk! ? 'Relay answered. You are good to go.' : 'Relay did not answer.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ExpressiveButton(
                                label: _testing ? 'Testing…' : 'Save & test',
                                icon: Icons.wifi_tethering_rounded,
                                tone: ExpressiveTone.tonal,
                                height: 52,
                                expanded: true,
                                onPressed: _testing ? null : _testRelay,
                              ),
                            ),
                            const SizedBox(width: 10),
                            ExpressiveButton(
                              label: 'Reset',
                              tone: ExpressiveTone.glass,
                              height: 52,
                              onPressed: () {
                                _serverController.text = app.baseConfig.serverUrl;
                                app.setServerOverride(null);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            LiveRelayStatus(status: app.relayStatus),
                            const Spacer(),
                            Text(
                              Uri.tryParse(app.config.serverUrl)?.authority ?? app.config.serverUrl,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _section(
                    context,
                    title: 'About',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ComeOver 0.1.0 · built for phones, tablets, Fire TV, Android TV and iPhone.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Invites last 6 hours. Locations live in memory on your relay and are never '
                          'written to a database. Maps © OpenStreetMap contributors, tiles © CARTO.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, {required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          child,
        ],
      ),
    );
  }
}

class LiveRelayStatus extends StatelessWidget {
  const LiveRelayStatus({super.key, required this.status});

  final RelayStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.isLive
        ? Palette.mint
        : (status == RelayStatus.connecting || status == RelayStatus.reconnecting)
            ? Palette.lemon
            : Palette.peach;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          status.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
