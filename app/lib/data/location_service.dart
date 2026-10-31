import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';

class LocationFix {
  const LocationFix({
    required this.point,
    required this.accuracy,
    required this.timestamp,
    this.heading,
    this.speed,
    this.battery,
  });

  final LatLng point;
  final double accuracy;
  final DateTime timestamp;
  final double? heading;
  final double? speed;
  final double? battery;

  LocationFix shifted(LatLng next) => LocationFix(
        point: next,
        accuracy: accuracy,
        timestamp: timestamp,
        heading: heading,
        speed: speed,
        battery: battery,
      );

  /// Approximate mode: snap to a ~110 m grid so exact home addresses leak less.
  LocationFix coarsened() => shifted(LatLng(
        (point.latitude * 100).round() / 100,
        (point.longitude * 100).round() / 100,
      ));
}

enum LocationState { unknown, granted, denied, deniedForever, serviceDisabled, unsupported }

class LocationResult {
  const LocationResult(this.state, [this.fix]);

  final LocationState state;
  final LocationFix? fix;

  bool get ok => fix != null;
}

class LocationService {
  LocationService({required this.config});

  final AppConfig config;
  StreamSubscription<Position>? _subscription;
  LocationFix? _last;
  bool _demoAnnounced = false;

  /// When true, Android runs a foreground location service and iOS keeps
  /// background updates on. This is what lets the lock-screen countdown stay
  /// live while the app is backgrounded or the screen is off.
  bool backgroundUpdates = false;

  LocationFix? get last => _last;
  bool get hasDemoLocation => config.demoLocation != null;

  void setBackgroundUpdates(bool value) {
    backgroundUpdates = value;
  }

  /// Fire OS has no Google Play Services, so we deliberately use the platform
  /// LocationManager on Android. It also works on stock AOSP Android TV.
  LocationSettings get _settings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
        intervalDuration: const Duration(seconds: 2),
        forceLocationManager: true,
        foregroundNotificationConfig: backgroundUpdates
            ? const ForegroundNotificationConfig(
                notificationTitle: 'ComeOver is sharing your live location',
                notificationText: 'Your arrival countdown stays up to date on the lock screen.',
                notificationChannelName: 'Live location',
                notificationIcon: AndroidResource(name: 'ic_live_status', defType: 'drawable'),
                setOngoing: true,
                enableWakeLock: true,
                color: Color(0xFF9BF6FF),
              )
            : null,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
        allowBackgroundLocationUpdates: backgroundUpdates,
        showBackgroundLocationIndicator: backgroundUpdates,
        pauseLocationUpdatesAutomatically: false,
        activityType: ActivityType.other,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );
  }

  Future<LocationResult> ensureAndLocate() async {
    if (config.demoLocation != null) {
      final demo = _demoFix();
      _last = demo;
      return LocationResult(LocationState.granted, demo);
    }
    if (config.previewMode) {
      return const LocationResult(LocationState.unsupported);
    }
    if (kIsWeb) {
      // Browsers only expose geolocation on secure origins.
      final uri = Uri.base;
      final secure = uri.scheme == 'https' || uri.host == 'localhost' || uri.host == '127.0.0.1';
      if (!secure) return const LocationResult(LocationState.unsupported);
    }
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return LocationResult(LocationState.serviceDisabled, _last);
      }
    } catch (_) {
      // Some TV/emulator builds throw here; fall through and try anyway.
    }

    var permission = await _safeCheck();
    if (permission == LocationPermission.denied) {
      permission = await _safeRequest();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationResult(LocationState.deniedForever, _last);
    }
    if (permission == LocationPermission.denied) {
      return LocationResult(LocationState.denied, _last);
    }

    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: _settings)
          .timeout(const Duration(seconds: 12));
      final fix = _fromPosition(position);
      _last = fix;
      return LocationResult(LocationState.granted, fix);
    } catch (_) {
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          final fix = _fromPosition(position);
          _last = fix;
          return LocationResult(LocationState.granted, fix);
        }
      } catch (_) {
        // ignore
      }
      return LocationResult(LocationState.granted, _last);
    }
  }

  Stream<LocationFix> watch() {
    if (config.demoLocation != null) {
      return Stream<LocationFix>.periodic(const Duration(seconds: 2), (_) {
        return _demoFix(drift: !_demoAnnounced ? 0 : 2.5);
      });
    }
    _subscription?.cancel();
    final controller = StreamController<LocationFix>.broadcast();
    try {
      _subscription = Geolocator.getPositionStream(locationSettings: _settings).listen(
        (position) {
          final fix = _fromPosition(position);
          _last = fix;
          if (!controller.isClosed) controller.add(fix);
        },
        onError: (Object _) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Permission revoked mid-session, or platform without location support.
    }
    controller.onCancel = () {
      _subscription?.cancel();
      _subscription = null;
    };
    return controller.stream;
  }

  Future<LocationPermission> _safeCheck() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  Future<LocationPermission> _safeRequest() async {
    try {
      return await Geolocator.requestPermission();
    } catch (_) {
      return LocationPermission.deniedForever;
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() => stop();

  LocationFix _fromPosition(Position position) => LocationFix(
        point: LatLng(position.latitude, position.longitude),
        accuracy: position.accuracy,
        timestamp: position.timestamp,
        heading: position.heading >= 0 ? position.heading : null,
        speed: position.speed >= 0 ? position.speed : null,
      );

  LocationFix _demoFix({double drift = 0}) {
    final seed = config.demoLocation!;
    _demoAnnounced = true;
    return LocationFix(
      point: LatLng(seed.lat + drift / 111320, seed.lng + drift / 90000),
      accuracy: 12,
      timestamp: DateTime.now(),
      heading: 45,
      speed: 1.3,
    );
  }
}
