import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const double earthRadiusMeters = 6371008.8;
const double _degToRad = math.pi / 180;
const double _radToDeg = 180 / math.pi;

double _rad(double degrees) => degrees * _degToRad;

/// Great-circle distance in metres.
double distanceMeters(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
}

/// Initial bearing from [a] to [b] in degrees clockwise from north.
double bearingDegrees(LatLng a, LatLng b) {
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (_radToDeg * math.atan2(y, x) + 360) % 360;
}

/// Point [meters] away from [origin] along [bearing] degrees.
LatLng destination(LatLng origin, double meters, double bearing) {
  final d = meters / earthRadiusMeters;
  final brng = _rad(bearing);
  final lat1 = _rad(origin.latitude);
  final lng1 = _rad(origin.longitude);
  final lat2 = math.asin(
    math.sin(lat1) * math.cos(d) +
        math.cos(lat1) * math.sin(d) * math.cos(brng),
  );
  final lng2 =
      lng1 +
      math.atan2(
        math.sin(brng) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2),
      );
  return LatLng(_radToDeg * lat2, ((_radToDeg * lng2 + 540) % 360) - 180);
}

/// Interpolate between two points (used to animate markers smoothly).
LatLng lerpLatLng(LatLng a, LatLng b, double t) {
  final clamped = t.clamp(0.0, 1.0);
  final lat = a.latitude + (b.latitude - a.latitude) * clamped;
  final lngDelta = ((b.longitude - a.longitude + 540) % 360) - 180;
  final lng = a.longitude + lngDelta * clamped;
  return LatLng(lat, ((lng + 540) % 360) - 180);
}

double normalizeBearing(double degrees) => (degrees % 360 + 360) % 360;

/// Straight-line speed when the traveller's GPS speed is unavailable.
double assumedSpeed(double? reported, {bool driving = false}) {
  if (reported != null && reported > 0.6 && reported < 45) return reported;
  return driving ? 9.0 : 1.35;
}

/// Rough street-network factor: the crow flies, the road rarely does.
const double routeFactor = 1.18;
