import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum DeviceClass { phone, tablet, tv }

/// Android's UI mode is the most reliable TV signal (d-pad navigation hints are
/// not always set, and Fire OS is still Android underneath).
Future<bool> detectTelevision() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    const channel = MethodChannel('dev.comeover/device');
    return await channel.invokeMethod<bool>('isTelevision') ?? false;
  } catch (_) {
    return false;
  }
}

/// Layout + input personality. TVs get 10-foot spacing, focus rings and
/// generous overscan; tablets get a two-pane layout in landscape.
class DeviceProfile {
  const DeviceProfile({
    required this.kind,
    required this.size,
    required this.overscan,
    required this.textScale,
  });

  final DeviceClass kind;
  final Size size;
  final EdgeInsets overscan;
  final double textScale;

  bool get isTv => kind == DeviceClass.tv;
  bool get isTablet => kind == DeviceClass.tablet;
  bool get isCompact => size.shortestSide < 600;

  /// Width available after safe-area + TV overscan.
  double get contentWidth => size.width - overscan.horizontal;
  bool get isExpanded => size.width >= 1000;
  bool get isMedium => size.width >= 720 && size.width < 1000;

  static DeviceProfile of(
    BuildContext context, {
    bool? forceTv,
    double? scaleOverride,
  }) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final navigation = media.navigationMode;
    final directional = navigation == NavigationMode.directional;
    final tv = forceTv ?? directional;
    final tablet = !tv && size.shortestSide >= 600;
    final kind = tv
        ? DeviceClass.tv
        : tablet
        ? DeviceClass.tablet
        : DeviceClass.phone;
    final base = tv
        ? const EdgeInsets.fromLTRB(42, 32, 42, 48)
        : EdgeInsets.zero;
    return DeviceProfile(
      kind: kind,
      size: size,
      overscan: EdgeInsets.fromLTRB(
        base.left + media.padding.left,
        base.top + media.padding.top,
        base.right + media.padding.right,
        base.bottom + media.padding.bottom,
      ),
      textScale: scaleOverride ?? media.textScaler.scale(1),
    );
  }

  String get label => switch (kind) {
    DeviceClass.tv => 'TV',
    DeviceClass.tablet => 'Tablet',
    DeviceClass.phone => 'Phone',
  };
}
