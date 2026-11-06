import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app.dart';
import '../core/theme.dart';
import '../ui/expressive.dart';
import '../ui/glass.dart';
import '../ui/map_style.dart';

/// Meeting-point picker. Works with touch and a TV d-pad (arrows pan, OK
/// confirms) — useful on Fire TV where there is no GPS at all.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({
    super.key,
    required this.initial,
    this.title = 'Set your meeting point',
    this.confirmLabel = 'Use this point',
  });

  final LatLng initial;
  final String title;
  final String confirmLabel;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _mapController = MapController();
  final _mapFocus = FocusNode(debugLabel: 'map-picker');
  late LatLng _center = widget.initial;
  double _zoom = 15;
  bool _mapReady = false;

  @override
  void dispose() {
    _mapFocus.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.of(context).pop(_center);

  Future<void> _useMyLocation() async {
    final app = AppScope.of(context);
    final ok = await app.retryLocation();
    if (!ok) return;
    final point = app.myPoint;
    if (point == null) return;
    setState(() => _center = point);
    _moveTo(point, 16);
  }

  void _moveTo(LatLng point, [double? zoom]) {
    final next = zoom ?? _zoom;
    setState(() {
      _center = point;
      _zoom = next;
    });
    if (_mapReady) _mapController.move(point, next);
  }

  void _nudge(double dx, double dy) {
    final scale = 0.0025 * (16 / _zoom.clamp(3, 19));
    _moveTo(
      LatLng(
        (_center.latitude + dy * scale).clamp(-85, 85),
        ((_center.longitude + dx * scale + 540) % 360) - 180,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _nudge(-1, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _nudge(1, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _nudge(0, 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _nudge(0, -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.select:
        _confirm();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final device = DeviceScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = AppStyle.of(context);

    return Scaffold(
      backgroundColor: style.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: _zoom,
              minZoom: 3,
              maxZoom: 19,
              backgroundColor: style.ink,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                // The picker's own Focus() already maps arrows to nudges;
                // the map's built-in keyboard handler would otherwise
                // autofocus itself and double-handle (or swallow) keys.
                keyboardOptions: KeyboardOptions.disabled(),
              ),
              onMapReady: () => setState(() => _mapReady = true),
              onPositionChanged: (camera, hasGesture) {
                if (!mounted) return;
                setState(() {
                  _center = camera.center;
                  _zoom = camera.zoom;
                });
              },
            ),
            children: [
              const MapTiles(),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 1,
                    height: 1,
                    child: const SizedBox.shrink(),
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
                    style.ink.withValues(alpha: 0.72),
                    Colors.transparent,
                    Colors.transparent,
                    style.ink.withValues(alpha: 0.82),
                  ],
                  stops: const [0, 0.22, 0.62, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(child: _Crosshair(color: style.live)),
            ),
          ),
          SafeArea(
            child: Focus(
              focusNode: _mapFocus,
              autofocus: device.isTv,
              onKeyEvent: _onKey,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: device.isTv ? 44 : 16,
                  vertical: 14,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GlassIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (device.isTv)
                          const RemoteHint(
                            labels: ['◀ ▶ move', 'OK confirm'],
                            compact: true,
                          ),
                      ],
                    ),
                    const Spacer(),
                    Glass(
                      borderRadius: 32,
                      padding: EdgeInsets.all(device.isTv ? 26 : 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.pin_drop_outlined,
                                size: 20,
                                color: style.live,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Drag the map or use the remote to place the pin.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  letterSpacing: 1,
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              GlassIconButton(
                                icon: Icons.zoom_in_rounded,
                                tooltip: 'Zoom in',
                                onPressed: () =>
                                    _moveTo(_center, (_zoom + 1).clamp(3, 19)),
                              ),
                              const SizedBox(width: 8),
                              GlassIconButton(
                                icon: Icons.zoom_out_rounded,
                                tooltip: 'Zoom out',
                                onPressed: () =>
                                    _moveTo(_center, (_zoom - 1).clamp(3, 19)),
                              ),
                              const SizedBox(width: 8),
                              GlassIconButton(
                                icon: Icons.my_location_rounded,
                                tooltip: 'Use my location',
                                onPressed: _useMyLocation,
                              ),
                              const Spacer(),
                              Flexible(
                                flex: 3,
                                child: ExpressiveButton(
                                  label: widget.confirmLabel,
                                  icon: Icons.check_rounded,
                                  expanded: true,
                                  autofocus: !device.isTv,
                                  height: 54,
                                  onPressed: _confirm,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(right: 10, bottom: 6, child: MapCredit()),
        ],
      ),
    );
  }
}

class _Crosshair extends StatelessWidget {
  const _Crosshair({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(painter: _CrosshairPainter(color)),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  _CrosshairPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(center, 16, ring);

    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, 16, shadow);

    final dot = Paint()..color = color;
    canvas.drawCircle(center, 4, dot);

    final arm = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawLine(center.translate(0, -30), center.translate(0, -22), arm);
    canvas.drawLine(center.translate(0, 22), center.translate(0, 30), arm);
    canvas.drawLine(center.translate(-30, 0), center.translate(-22, 0), arm);
    canvas.drawLine(center.translate(22, 0), center.translate(30, 0), arm);
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => old.color != color;
}
