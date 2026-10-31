import 'package:comeover/core/geo.dart';
import 'package:comeover/models/member.dart';
import 'package:comeover/models/travel_estimate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Member travellerAt(LatLng point, {double? speed, double accuracy = 12}) {
  return Member(
    id: 'm1',
    name: 'Maya Rao',
    avatar: '🐼',
    colorHex: '#9BF6FF',
    isHost: false,
    online: true,
    location: MemberLocation(
      point: point,
      accuracy: accuracy,
      timestamp: DateTime(2026, 1, 1),
      speed: speed,
    ),
    hasLocation: true,
  );
}

void main() {
  const origin = LatLng(12.9716, 77.5946);
  final now = DateTime(2026, 1, 1, 12, 0, 5);

  TravelEstimate estimateAt(LatLng point, {double start = 1000}) {
    return TravelEstimate.between(
      traveller: travellerAt(point),
      origin: origin,
      arrivalRadius: 40,
      now: now,
      receivedAt: DateTime(2026, 1, 1, 12, 0, 0),
      startMeters: start,
    );
  }

  test('measures distance, ETA and compass from the origin', () {
    final estimate = estimateAt(destination(origin, 1000, 0));
    expect(estimate.meters, closeTo(1000, 1));
    expect(estimate.eta.inSeconds, greaterThan(0));
    expect(estimate.arrived, isFalse);
    expect(estimate.compass, 'north');
    expect(estimate.progress, closeTo(0, 0.02));
    expect(estimate.countdown.inSeconds, greaterThan(0));
    expect(estimate.stale, isFalse);
  });

  test('arrival radius flips the estimate into arrived', () {
    final estimate = estimateAt(destination(origin, 20, 90));
    expect(estimate.arrived, isTrue);
    expect(estimate.countdown, Duration.zero);
    expect(estimate.progress, closeTo(1, 0.02));
    expect(estimate.compass, 'east');
  });

  test('stale positions are flagged after 45 seconds', () {
    final estimate = TravelEstimate.between(
      traveller: travellerAt(destination(origin, 500, 0)),
      origin: origin,
      arrivalRadius: 40,
      now: now.add(const Duration(seconds: 46)),
      receivedAt: now,
      startMeters: 1000,
    );
    expect(estimate.stale, isTrue);
    expect(estimate.staleFor.inSeconds, 46);
  });

  test('reported speed is used when it is plausible', () {
    final walking = estimateAt(destination(origin, 1000, 0));
    final fast = TravelEstimate.between(
      traveller: travellerAt(destination(origin, 1000, 0), speed: 12),
      origin: origin,
      arrivalRadius: 40,
      now: now,
      receivedAt: now,
      startMeters: 1000,
    );
    expect(fast.eta, lessThan(walking.eta));
    expect(fast.speed, closeTo(12, 0.001));
  });

  test('progress is clamped for malformed start distances', () {
    final estimate = estimateAt(destination(origin, 30, 0), start: 30);
    expect(estimate.progress, 1);
  });
}
