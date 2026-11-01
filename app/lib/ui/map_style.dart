import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../core/theme.dart';

/// OpenStreetMap's standard raster tiles — keyless and fine for an app's
/// modest personal use with attribution. The muted dark look is applied as a
/// colour matrix instead of relying on a separate basemap style, because
/// CARTO's previously free dark tiles now require an API key.
class MapTiles extends StatelessWidget {
  const MapTiles({super.key, this.dark = true});

  final bool dark;

  /// Grayscale the tiles, pull them down to a dark ramp and add a whisper of
  /// cool bias so streets stay readable under the tint.
  static const _darkMatrix = <double>[
    0.2126 * 0.34, 0.7152 * 0.34, 0.0722 * 0.34, 0, 0.02, //
    0.2126 * 0.36, 0.7152 * 0.36, 0.0722 * 0.36, 0, 0.03,
    0.2126 * 0.42, 0.7152 * 0.42, 0.0722 * 0.42, 0, 0.05,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    Widget tilebuilder(BuildContext context, Widget tileWidget, TileImage tile) {
      final tinted = ColorFiltered(
        colorFilter: ColorFilter.mode(
          style.mapTint.withValues(alpha: style.isMaterial ? 0.10 : 0.16),
          style.mapTintBlend,
        ),
        child: tileWidget,
      );
      return dark
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix(_darkMatrix),
              child: tinted,
            )
          : tinted;
    }

    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'dev.comeover.app',
      maxNativeZoom: 19,
      maxZoom: 19,
      tileBuilder: tilebuilder,
    );
  }
}

class MapCredit extends StatelessWidget {
  const MapCredit({super.key, this.dark = true});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: dark ? 0.28 : 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '© OpenStreetMap contributors',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 9,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
