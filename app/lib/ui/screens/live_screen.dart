import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../core/device.dart';
import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../data/realtime.dart';
import '../../models/member.dart';
import '../../models/travel_estimate.dart';
import '../../state/app_controller.dart';
import '../brand.dart';
import '../expressive.dart';
import '../glass.dart';
import '../map_style.dart';
import '../settings_sheet.dart';

/// The room, live: a full-bleed map, a glass HUD and one very large
/// countdown. On TVs and tablets the HUD becomes a right-hand rail so the
/// map keeps the whole left pane.
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _map = MapController();
  bool _mapReady = false;
  bool _follow = true;
  String? _fitKey;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  bool _isWide(DeviceProfile device) =>
      device.size.width >= 900 && device.size.width > device.size.height + 80;

  List<LatLng> _routePoints(AppController app) {
    final points = <LatLng>[];
    final origin = app.originPoint;
    if (origin != null) points.add(origin);
    for (final member in app.trackable) {
      final location = member.location;
      if (location != null) points.add(location.point);
    }
    return points;
  }

  void _scheduleFit(
    AppController app, {
    required bool wide,
    bool force = false,
  }) {
    if (!_mapReady || !_follow) return;
    final traveller = app.trackedMember;
    final key = '${traveller?.id}:${app.originPoint?.hashCode}';
    if (!force && key == _fitKey) return;
    _fitKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      final points = _routePoints(app);
      if (points.isEmpty) return;
      final bounds = LatLngBounds.fromPoints(points);
      final visible = _map.camera.visibleBounds;
      if (!force && visible.containsBounds(bounds)) return;
      if (points.length == 1) {
        _map.move(points.first, 16);
        return;
      }
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: EdgeInsets.fromLTRB(72, 96, 72, wide ? 120 : 260),
          maxZoom: 17,
          minZoom: 11,
        ),
      );
    });
  }

  Future<void> _shareEta(AppController app, TravelEstimate? estimate) async {
    final text = estimate == null
        ? 'Come over — join my ComeOver room with code ${app.roomCode}.\n${app.inviteLink}'
        : '${memberFirstName(estimate.traveller)} is ${formatDistance(estimate.meters, app.units)} away — '
              'ETA ${formatDuration(estimate.eta, precise: false)}.\n'
              '${formatArrival(estimate.arrivalAt)}\nTrack live: ${app.inviteLink}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'ComeOver ETA'),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) app.showNotice('ETA copied to clipboard');
    }
  }

  Future<void> _leave(AppController app) async {
    final host = app.isHost;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(host ? 'Close the room?' : 'Leave the room?'),
        content: Text(
          host
              ? 'Everyone loses the live view immediately and the invite stops working.'
              : 'Your position stops sharing and you leave the live map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(host ? 'Close room' : 'Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (host) {
      await app.endRoom();
    } else {
      await app.leaveRoom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final device = DeviceScope.of(context);
    final estimate = app.estimate;
    final wide = _isWide(device);
    final dark = Theme.of(context).brightness == Brightness.dark;

    _scheduleFit(app, wide: wide);

    final map = _MapStage(
      app: app,
      estimate: estimate,
      wide: wide,
      isTv: device.isTv,
      dark: dark,
      map: _map,
      onReady: () {
        if (_mapReady) return;
        setState(() => _mapReady = true);
        _scheduleFit(app, wide: wide, force: true);
      },
      onGesture: () {
        if (_follow) setState(() => _follow = false);
      },
      onRecenter: () {
        setState(() => _follow = true);
        _fitKey = null;
        _scheduleFit(app, wide: wide, force: true);
      },
      onSettings: () => openSettings(context),
      onLeave: () => _leave(app),
      following: _follow,
    );

    final overlay = Stack(
      fit: StackFit.expand,
      children: [
        if (wide)
          Row(
            children: [
              Expanded(child: map),
              // The rail is the only 10-foot control surface; on TV it earns
              // extra width so paired action buttons keep full labels.
              SizedBox(
                width: device.isTv ? 500 : 390,
                child: _Rail(
                  app: app,
                  device: device,
                  estimate: estimate,
                  onShare: () => _shareEta(app, estimate),
                  onSettings: () => openSettings(context),
                  onLeave: () => _leave(app),
                  onDemo: app.isHost
                      ? () async {
                          await app.startDemoTraveller();
                        }
                      : null,
                ),
              ),
            ],
          )
        else
          Stack(
            fit: StackFit.expand,
            children: [
              map,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: _CompactHud(
                    app: app,
                    device: device,
                    estimate: estimate,
                    onShare: () => _shareEta(app, estimate),
                    onSettings: () => openSettings(context),
                    onLeave: () => _leave(app),
                    onDemo: app.isHost
                        ? () async {
                            await app.startDemoTraveller();
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ),
        if (app.arrivalCelebration)
          _ArrivalOverlay(
            estimate: app.estimate!,
            units: app.units,
            onDismiss: app.dismissArrival,
          ),
      ],
    );
    return overlay;
  }
}

/* ------------------------------------------------------------------------ map */

class _MapStage extends StatelessWidget {
  const _MapStage({
    required this.app,
    required this.estimate,
    required this.wide,
    required this.isTv,
    required this.dark,
    required this.map,
    required this.onReady,
    required this.onGesture,
    required this.onRecenter,
    required this.onSettings,
    required this.onLeave,
    required this.following,
  });

  final AppController app;
  final TravelEstimate? estimate;
  final bool wide;
  final bool isTv;
  final bool dark;
  final MapController map;
  final VoidCallback onReady;
  final VoidCallback onGesture;
  final VoidCallback onRecenter;
  final VoidCallback onSettings;
  final VoidCallback onLeave;
  final bool following;

  LatLng get _initial {
    final origin = app.originPoint;
    if (origin != null) return origin;
    for (final member in app.trackable) {
      final location = member.location;
      if (location != null) return location.point;
    }
    return const LatLng(12.9716, 77.5946);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    final origin = app.originPoint;
    final tracked = app.trackedMember;
    final travellerPoint = tracked?.location?.point;
    final route = <LatLng>[?origin, ?travellerPoint];

    return Container(
      color: style.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: map,
            options: MapOptions(
              initialCenter: _initial,
              initialZoom: route.length > 1 ? 15 : 16,
              minZoom: 3,
              maxZoom: 19,
              backgroundColor: style.ink,
              // flutter_map's keyboard panning grabs focus on appearance and
              // swallows every arrow key — on TV that hijacks the d-pad, so
              // the user can only pan the map and never reach the rail
              // buttons. Disable it entirely on TV; arrows then move focus
              // between the real controls.
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                keyboardOptions: isTv
                    ? const KeyboardOptions.disabled()
                    : const KeyboardOptions(),
              ),
              onMapReady: onReady,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) onGesture();
              },
            ),
            children: [
              MapTiles(dark: dark),
              if (origin != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: origin,
                      radius: (app.room?.settings.arrivalRadius ?? 40).clamp(
                        15,
                        200,
                      ),
                      useRadiusInMeter: true,
                      color: style.live.withValues(alpha: 0.14),
                      borderColor: style.live.withValues(alpha: 0.55),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              if (route.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route,
                      strokeWidth: 12,
                      color: scheme.primary.withValues(alpha: 0.18),
                    ),
                    Polyline(
                      points: route,
                      strokeWidth: 3,
                      color: style.live.withValues(alpha: 0.9),
                      pattern: StrokePattern.dashed(segments: const [9, 8]),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (origin != null)
                    Marker(
                      point: origin,
                      width: 132,
                      height: 116,
                      alignment: Alignment.topCenter,
                      child: _OriginPin(
                        member: app.originMember,
                        label: app.viewingFromHost
                            ? (app.originMember?.name ?? 'Host')
                            : 'You',
                      ),
                    ),
                  for (final member in app.trackable)
                    Marker(
                      point: member.location!.point,
                      width: 150,
                      height: 132,
                      alignment: Alignment.topCenter,
                      child: _TravellerPin(
                        member: member,
                        selected: member.id == tracked?.id,
                        bearing: origin == null
                            ? null
                            : bearingDegrees(origin, member.location!.point),
                      ),
                    ),
                ],
              ),
            ],
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    style.ink.withValues(alpha: 0.78),
                    Colors.transparent,
                    Colors.transparent,
                    style.ink.withValues(alpha: wide ? 0.35 : 0.82),
                  ],
                  stops: const [0, 0.18, 0.68, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 20 : 12,
                10,
                wide ? 16 : 12,
                0,
              ),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: app.isHost ? 'Close room' : 'Leave room',
                    onPressed: onLeave,
                  ),
                  const SizedBox(width: 10),
                  _RoomPill(app: app),
                  const Spacer(),
                  if (app.sharingPaused)
                    const FrostChip(
                      label: 'Sharing paused',
                      tone: FrostTone.alert,
                      compact: true,
                      icon: Icon(Icons.pause_rounded, size: 13),
                    ),
                  if (kIsWeb && !app.isHost && app.isLive) ...[
                    const SizedBox(width: 8),
                    KeepAliveToggle(app: app),
                  ],
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Settings',
                    onPressed: onSettings,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            // TV bezels crop ~5% per edge; keep the zoom cluster inside it.
            left: wide ? (isTv ? 50 : 18) : 12,
            bottom: wide ? (isTv ? 56 : 18) : 228,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom in',
                  size: 44,
                  onPressed: () {
                    final camera = map.camera;
                    map.move(camera.center, (camera.zoom + 1).clamp(3, 19));
                  },
                ),
                const SizedBox(height: 8),
                GlassIconButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom out',
                  size: 44,
                  onPressed: () {
                    final camera = map.camera;
                    map.move(camera.center, (camera.zoom - 1).clamp(3, 19));
                  },
                ),
                const SizedBox(height: 8),
                GlassIconButton(
                  icon: following
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  tooltip: following ? 'Following' : 'Recenter',
                  size: 44,
                  tone: following ? style.live : null,
                  onPressed: onRecenter,
                ),
              ],
            ),
          ),
          Positioned(
            right: isTv ? 52 : 8,
            bottom: isTv ? 50 : 6,
            child: const MapCredit(),
          ),
        ],
      ),
    );
  }
}

/// Traveller-only, web-only experimental toggle: keeps the page (and the
/// location watcher) alive while the phone is locked by playing an
/// inaudible audio loop. Tapping it when off shows the plain-English
/// experimental disclosure before enabling.
class KeepAliveToggle extends StatelessWidget {
  const KeepAliveToggle({super.key, required this.app});

  final AppController app;

  Future<void> _prompt(BuildContext context) async {
    final enabled = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep tracking in the background?'),
        content: const Text(
          'Experimental: plays a near-silent audio loop so the browser keeps '
          'this page — and your location updates — alive while the screen is '
          'locked or you are using another app.\n\n'
          'Expect a small sound indicator on the lock screen and a little '
          'extra battery use. Calls and navigation voice prompts can '
          'interrupt it; if tracking freezes anyway, your position goes '
          'stale for the host until you reopen the page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (enabled == true) await app.setTravellerKeepAlive(true);
  }

  @override
  Widget build(BuildContext context) {
    final on = app.travellerKeepAlive;
    return GestureDetector(
      onTap: () {
        if (on) {
          app.setTravellerKeepAlive(false);
        } else {
          _prompt(context);
        }
      },
      child: FrostChip(
        label: on ? 'Background on' : 'Background off',
        compact: true,
        tone: on ? FrostTone.live : FrostTone.neutral,
        icon: Icon(
          on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          size: 13,
        ),
      ),
    );
  }
}

class _RoomPill extends StatelessWidget {
  const _RoomPill({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Glass(
      borderRadius: 999,
      blur: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveDot(size: 7),
          const SizedBox(width: 8),
          Text(
            app.roomCode,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              letterSpacing: 2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 1,
            height: 14,
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Text(
            app.relayStatus.label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _OriginPin extends StatelessWidget {
  const _OriginPin({required this.member, required this.label});

  final Member? member;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary,
                scheme.secondary.withValues(alpha: 0.85),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.55),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: member == null
              ? Icon(Icons.home_rounded, size: 24, color: scheme.onPrimary)
              : Text(
                  member!.avatar,
                  style: const TextStyle(fontSize: 26, height: 1),
                ),
        ),
        const SizedBox(height: 4),
        _PinLabel(text: label, accent: scheme.primary),
      ],
    );
  }
}

class _TravellerPin extends StatelessWidget {
  const _TravellerPin({
    required this.member,
    required this.selected,
    this.bearing,
  });

  final Member member;
  final bool selected;
  final double? bearing;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(member.colorHex);
    final style = AppStyle.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: selected ? 66 : 52,
          height: selected ? 66 : 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                ),
              AvatarBubble(
                member: member,
                size: selected ? 54 : 42,
                showStatus: true,
                glow: selected,
              ),
              if (bearing != null)
                Positioned(
                  right: selected ? 0 : 1,
                  top: selected ? 0 : 1,
                  child: Transform.rotate(
                    angle: (bearing! * math.pi) / 180,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: style.ink,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        Icons.navigation_rounded,
                        size: 13,
                        color: color,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _PinLabel(
          text: memberFirstName(member),
          accent: color,
          strong: selected,
        ),
      ],
    );
  }
}

class _PinLabel extends StatelessWidget {
  const _PinLabel({
    required this.text,
    required this.accent,
    this.strong = false,
  });

  final String text;
  final Color accent;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.light
        ? Colors.black87
        : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: (strong ? accent : style.ink).withValues(
          alpha: strong ? 0.92 : 0.80,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: strong
              ? Colors.white.withValues(alpha: 0.30)
              : style.chipBorder,
        ),
        boxShadow: strong
            ? [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 18)]
            : null,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: strong ? onAccent : scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------- compact */

class _CompactHud extends StatelessWidget {
  const _CompactHud({
    required this.app,
    required this.device,
    required this.estimate,
    required this.onShare,
    required this.onSettings,
    required this.onLeave,
    required this.onDemo,
  });

  final AppController app;
  final DeviceProfile device;
  final TravelEstimate? estimate;
  final VoidCallback onShare;
  final VoidCallback onSettings;
  final VoidCallback onLeave;
  final VoidCallback? onDemo;

  @override
  Widget build(BuildContext context) {
    return Glass(
      margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
      borderRadius: 32,
      padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (app.trackable.length > 1) ...[
            _TravellerSelector(app: app, compact: true),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CountdownRing(estimate: estimate, size: device.isTv ? 108 : 96),
              const SizedBox(width: 14),
              Expanded(
                child: _EstimateSummary(
                  app: app,
                  estimate: estimate,
                  dense: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ExpressiveButton(
                  label: estimate == null ? 'Invite' : 'Share ETA',
                  icon: Icons.ios_share_rounded,
                  height: 50,
                  expanded: true,
                  autofocus: device.isTv,
                  onPressed: onShare,
                ),
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: app.sharingPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                tooltip: app.sharingPaused ? 'Resume sharing' : 'Pause sharing',
                size: 46,
                onPressed: () => app.setSharingPaused(!app.sharingPaused),
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Settings',
                size: 46,
                onPressed: onSettings,
              ),
              if (onDemo != null) ...[
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icons.auto_awesome_rounded,
                  tooltip: 'Add a demo traveller',
                  size: 46,
                  onPressed: onDemo,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------------------- rail */

class _Rail extends StatelessWidget {
  const _Rail({
    required this.app,
    required this.device,
    required this.estimate,
    required this.onShare,
    required this.onSettings,
    required this.onLeave,
    required this.onDemo,
  });

  final AppController app;
  final DeviceProfile device;
  final TravelEstimate? estimate;
  final VoidCallback onShare;
  final VoidCallback onSettings;
  final VoidCallback onLeave;
  final VoidCallback? onDemo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      left: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          device.isTv ? 20 : 14,
          12,
          device.isTv ? 28 : 14,
          // The rail is the full height of the screen; a TV bezel crops the
          // bottom most, so give the last rows room to breathe.
          device.isTv ? 30 : 12,
        ),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Wordmark(compact: true),
                    const Spacer(),
                    if (app.sharingPaused)
                      const FrostChip(
                        label: 'Paused',
                        tone: FrostTone.alert,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Glass(
                  borderRadius: 36,
                  padding: EdgeInsets.all(device.isTv ? 28 : 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              estimate == null
                                  ? 'Waiting for movement'
                                  : 'Incoming',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          FrostChip(
                            label: 'LIVE',
                            tone: FrostTone.live,
                            compact: true,
                            icon: const LiveDot(size: 6),
                          ),
                        ],
                      ),
                      if (app.trackable.length > 1) ...[
                        const SizedBox(height: 14),
                        _TravellerSelector(app: app, compact: false),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _CountdownRing(
                            estimate: estimate,
                            size: device.isTv ? 132 : 116,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _EstimateSummary(
                              app: app,
                              estimate: estimate,
                              dense: false,
                            ),
                          ),
                        ],
                      ),
                      if (estimate != null) ...[
                        const SizedBox(height: 18),
                        _RouteMeter(estimate: estimate!),
                        const SizedBox(height: 10),
                        _Freshness(estimate: estimate!, now: app.now),
                      ],
                      const SizedBox(height: 18),
                      ExpressiveButton(
                        label: estimate == null ? 'Share invite' : 'Share ETA',
                        icon: Icons.ios_share_rounded,
                        expanded: true,
                        height: device.isTv ? 56 : 54,
                        autofocus: device.isTv,
                        onPressed: onShare,
                      ),
                      const SizedBox(height: 10),
                      // Pair the secondary actions so the big screen is
                      // used for the map, not for one button per row.
                      Row(
                        children: [
                          Expanded(
                            child: ExpressiveButton(
                              label: app.sharingPaused
                                  ? 'Resume sharing'
                                  : 'Pause sharing',
                              icon: app.sharingPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              tone: ExpressiveTone.tonal,
                              height: device.isTv ? 52 : 48,
                              expanded: true,
                              onPressed: () =>
                                  app.setSharingPaused(!app.sharingPaused),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GlassIconButton(
                            icon: Icons.tune_rounded,
                            tooltip: 'Settings',
                            size: device.isTv ? 52 : 48,
                            onPressed: onSettings,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (onDemo != null) ...[
                            Expanded(
                              child: ExpressiveButton(
                                label: 'Demo walk',
                                icon: Icons.auto_awesome_rounded,
                                tone: ExpressiveTone.glass,
                                height: device.isTv ? 52 : 46,
                                expanded: true,
                                onPressed: onDemo,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: ExpressiveButton(
                              label: app.isHost ? 'Close room' : 'Leave',
                              icon: app.isHost
                                  ? Icons.close_rounded
                                  : Icons.logout_rounded,
                              tone: ExpressiveTone.danger,
                              height: device.isTv ? 52 : 46,
                              expanded: true,
                              onPressed: onLeave,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Glass(
                  borderRadius: 30,
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel(
                        'In the room',
                        trailing: Text(
                          '${app.members.length}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final member in app.members)
                        _MemberRow(
                          app: app,
                          member: member,
                          selected: member.id == app.trackedMember?.id,
                        ),
                      if (app.isHost && app.trackable.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Share the code or start a demo walk to preview the live view.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        app.viewingFromHost
                            ? 'Distances are measured from ${app.originMember?.name ?? 'the host'} — this screen has no GPS.'
                            : 'Sharing stops the moment this room closes.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TravellerSelector extends StatelessWidget {
  const _TravellerSelector({required this.app, required this.compact});

  final AppController app;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final candidates = app.trackable;
    if (candidates.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: compact ? 38 : 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: candidates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final member = candidates[index];
          return _TravellerChip(
            member: member,
            selected: member.id == app.trackedMember?.id,
            onTap: () => app.focusMember(member.id),
          );
        },
      ),
    );
  }
}

class _TravellerChip extends StatefulWidget {
  const _TravellerChip({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TravellerChip> createState() => _TravellerChipState();
}

class _TravellerChipState extends State<_TravellerChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    final color = colorFromHex(widget.member.colorHex);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (value) => setState(() => _focused = value),
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.fromLTRB(5, 4, 13, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: widget.selected
                ? color.withValues(alpha: 0.22)
                : style.chipFill,
            border: Border.all(
              color: widget.selected
                  ? color
                  : _focused
                  ? scheme.secondary
                  : style.chipBorder,
              width: widget.selected || _focused ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.28),
                ),
                child: Text(
                  widget.member.avatar,
                  style: const TextStyle(fontSize: 15, height: 1),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                memberFirstName(widget.member),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: widget.selected
                      ? Colors.white
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.app,
    required this.member,
    required this.selected,
  });

  final AppController app;
  final Member member;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    final mine = member.id == app.me?.id;
    final origin = app.originPoint;
    final distance = !mine && member.location != null && origin != null
        ? distanceMeters(origin, member.location!.point)
        : null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: mine || !member.canTrack ? null : () => app.focusMember(member.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? scheme.primary.withValues(alpha: 0.10)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            AvatarBubble(
              member: member,
              size: 34,
              showStatus: true,
              glow: selected,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          mine ? '${member.name} (you)' : member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (member.isHost) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.key_rounded, size: 13, color: style.caution),
                      ],
                      if (member.demo) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 12,
                          color: style.accent,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    mine
                        ? (app.sharingPaused
                              ? 'Not sharing'
                              : 'Sharing this device')
                        : !member.online
                        ? 'Offline'
                        : member.isTv
                        ? 'Watching on TV'
                        : member.canTrack
                        ? motionLabel(member.location?.speed)
                        : 'No location yet',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (distance != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  formatDistance(distance, app.units, compact: true),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            if (app.isHost && !mine)
              SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Remove ${member.name}',
                  iconSize: 16,
                  onPressed: () => _remove(context, app, member),
                  icon: Icon(
                    Icons.person_remove_alt_1_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    AppController app,
    Member member,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: const Text(
          'They leave the room immediately and their dot disappears.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await app.removeMember(member.id);
  }
}

/* ----------------------------------------------------------------------- hud */

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.estimate, required this.size});

  final TravelEstimate? estimate;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    final value = estimate?.progress ?? 0;
    final arrived = estimate?.arrived ?? false;
    return ProgressRing(
      value: value,
      size: size,
      stroke: size * 0.075,
      colors: arrived
          ? [style.live, style.caution, style.live]
          : [style.live, style.accent, style.warm],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            arrived
                ? '0:00'
                : (estimate == null
                      ? '—:—'
                      : formatCountdown(estimate!.countdown)),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: size * 0.235,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: arrived ? style.live : scheme.onSurface,
            ),
          ),
          Text(
            arrived ? 'here' : 'left',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

class _EstimateSummary extends StatelessWidget {
  const _EstimateSummary({
    required this.app,
    required this.estimate,
    required this.dense,
  });

  final AppController app;
  final TravelEstimate? estimate;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appStyle = AppStyle.of(context);
    final value = estimate;
    if (value == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            app.trackable.isEmpty ? 'Nobody moving yet' : 'No distance yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 3),
          Text(
            app.trackable.isEmpty
                ? 'Invite someone or start a demo to see the countdown.'
                : 'Waiting for a position from ${app.trackedMember?.name ?? 'them'}.',
            maxLines: dense ? 2 : 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                memberFirstName(value.traveller),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              value.stale ? Icons.wifi_off_rounded : Icons.near_me_rounded,
              size: 15,
              color: value.stale ? appStyle.warm : appStyle.live,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value.arrived
              ? 'At the meeting point'
              : '${motionLabel(value.traveller.location?.speed)} · approaching from the ${value.compass}',
          maxLines: dense ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatValue(
                label: 'Distance',
                value: formatDistance(value.meters, app.units),
                accent: value.arrived ? appStyle.live : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatValue(
                label: 'ETA',
                value: value.arrived
                    ? 'now'
                    : formatDuration(value.eta, precise: false),
                sub: value.arrived ? null : formatClock(value.arrivalAt),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteMeter extends StatelessWidget {
  const _RouteMeter({required this.estimate});

  final TravelEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ROUTE PROGRESS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.4,
              ),
            ),
            const Spacer(),
            Text(
              '${(estimate.progress * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: estimate.progress.clamp(0, 1)),
            duration: Motion.slow,
            curve: Motion.emphasizedDecelerate,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: scheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              valueColor: AlwaysStoppedAnimation(style.live),
            ),
          ),
        ),
      ],
    );
  }
}

class _Freshness extends StatelessWidget {
  const _Freshness({required this.estimate, required this.now});

  final TravelEstimate estimate;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final age = now.difference(estimate.receivedAt);
    final stale = age > const Duration(seconds: 45);
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);
    return Row(
      children: [
        Icon(
          stale ? Icons.warning_amber_rounded : Icons.bolt_rounded,
          size: 14,
          color: stale ? style.warm : style.live,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            stale
                ? 'Last position ${formatAgo(age)} — countdown is paused.'
                : 'Position updated ${formatAgo(age)} · accuracy ±${formatDistance(estimate.accuracy, UnitSystem.metric, compact: true)}',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: stale ? style.warm : scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ arrival */

class _ArrivalOverlay extends StatefulWidget {
  const _ArrivalOverlay({
    required this.estimate,
    required this.units,
    required this.onDismiss,
  });

  final TravelEstimate estimate;
  final UnitSystem units;
  final VoidCallback onDismiss;

  @override
  State<_ArrivalOverlay> createState() => _ArrivalOverlayState();
}

class _ArrivalOverlayState extends State<_ArrivalOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final traveller = widget.estimate.traveller;
    final color = colorFromHex(traveller.colorHex);
    final style = AppStyle.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: style.scrim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Glass(
                borderRadius: 42,
                blur: 26,
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Opacity(
                                  opacity:
                                      (1 - ((_pulse.value + i / 3) % 1)) * 0.55,
                                  child: Container(
                                    width:
                                        78 + ((_pulse.value + i / 3) % 1) * 70,
                                    height:
                                        78 + ((_pulse.value + i / 3) % 1) * 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: color,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              child!,
                            ],
                          );
                        },
                        child: AvatarBubble(
                          member: traveller,
                          size: 82,
                          showStatus: false,
                          glow: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${memberFirstName(traveller)} is here',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.estimate.meters <= widget.estimate.arrivalRadius
                          ? 'Inside the arrival circle · ${formatDistance(widget.estimate.meters, widget.units)} from the meeting point.'
                          : 'Right on time.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: ExpressiveButton(
                            label: 'Dismiss',
                            tone: ExpressiveTone.tonal,
                            expanded: true,
                            height: 52,
                            onPressed: widget.onDismiss,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ExpressiveButton(
                            label: 'Open the door',
                            icon: Icons.door_front_door_rounded,
                            expanded: true,
                            height: 52,
                            autofocus: true,
                            onPressed: widget.onDismiss,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
