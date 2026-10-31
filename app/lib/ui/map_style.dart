import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../core/theme.dart';

/// CARTO's dark/light basemaps. They're free for reasonable use with
/// attribution, and the muted palette lets glass UI breathe.
class MapTiles extends StatelessWidget {
  const MapTiles({super.key, this.dark = true});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final style = dark ? 'dark_all' : 'light_all';
    return TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/$style/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: 'dev.comeover.app',
      maxNativeZoom: 19,
      maxZoom: 19,
      tileBuilder: dark
          ? (context, tileWidget, tile) => ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Palette.violet.withValues(alpha: 0.10),
                  BlendMode.softLight,
                ),
                child: tileWidget,
              )
          : null,
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
          '© OpenStreetMap · CARTO',
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
