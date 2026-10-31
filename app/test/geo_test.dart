import 'package:comeover/core/geo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide normalizeBearing;

void main() {
  group('distanceMeters', () {
    test('is zero for the same point', () {
      const point = LatLng(12.9716, 77.5946);
      expect(distanceMeters(point, point), closeTo(0, 0.001));
    });

    test('approximates one degree of latitude', () {
      final meters = distanceMeters(const LatLng(0, 0), const LatLng(1, 0));
      expect(meters, closeTo(111195, 200));
    });

    test('round-trips through destination', () {
      const origin = LatLng(51.5074, -0.1278);
      final target = destination(origin, 1250, 73);
      expect(distanceMeters(origin, target), closeTo(1250, 1));
    });
  });

  group('bearing', () {
    test('north is zero and east is 90', () {
      const origin = LatLng(10, 20);
      expect(bearingDegrees(origin, const LatLng(11, 20)), closeTo(0, 0.2));
      expect(bearingDegrees(origin, const LatLng(10, 21)), closeTo(90, 0.3));
    });
  });

  test('destination wraps longitude and stays on the globe', () {
    final point = destination(const LatLng(0, 179.9), 50000, 90);
    expect(point.longitude, lessThan(-179));
    expect(point.latitude.abs(), lessThan(1));
  });

  test('lerpLatLng crosses the date line the short way', () {
    final mid = lerpLatLng(const LatLng(0, 179), const LatLng(0, -179), 0.5);
    expect(mid.longitude.abs(), closeTo(180, 0.01));
  });

  test('assumedSpeed falls back to walking or driving', () {
    expect(assumedSpeed(null), closeTo(1.35, 0.001));
    expect(assumedSpeed(null, driving: true), closeTo(9, 0.001));
    expect(assumedSpeed(3.2), closeTo(3.2, 0.001));
    expect(assumedSpeed(90), closeTo(1.35, 0.001));
  });

  test('normalizeBearing keeps values in 0..360', () {
    expect(normalizeBearing(-90), closeTo(270, 0.001));
    expect(normalizeBearing(450), closeTo(90, 0.001));
  });
}
