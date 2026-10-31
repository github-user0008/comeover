import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import 'member.dart';

/// Everything the HUD needs to describe one traveller's approach.
class TravelEstimate {
  const TravelEstimate({
    required this.traveller,
    required this.origin,
    required this.meters,
    required this.accuracy,
    required this.eta,
    required this.arrivalAt,
    required this.progress,
    required this.now,
    required this.receivedAt,
    required this.arrivalRadius,
    required this.startMeters,
  });

  final Member traveller;
  final LatLng origin;
  final double meters;
  final double accuracy;
  final Duration eta;
  final DateTime arrivalAt;
  final double progress; // 0..1 along the route
  final DateTime now;
  final DateTime receivedAt;
  final double arrivalRadius;
  final double startMeters;

  bool get arrived => meters <= arrivalRadius;

  bool get stale => now.difference(receivedAt) > const Duration(seconds: 45);

  Duration get staleFor => now.difference(receivedAt);

  Duration get countdown {
    if (arrived) return Duration.zero;
    final left = arrivalAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  double get speed => assumedSpeed(
        traveller.location?.speed,
        driving: (traveller.location?.speed ?? 0) > 5,
      );

  String get compass => compassLabel(bearingDegrees(origin, traveller.location!.point));

  bool get isApproximate => accuracy >= 90;

  factory TravelEstimate.between({
    required Member traveller,
    required LatLng origin,
    required double arrivalRadius,
    required DateTime now,
    required DateTime receivedAt,
    double? startMeters,
  }) {
    final location = traveller.location!;
    final meters = distanceMeters(origin, location.point);
    final speed = assumedSpeed(
      location.speed,
      driving: (location.speed ?? 0) > 5,
    );
    final seconds = ((meters * routeFactor) / speed).clamp(0, 24 * 3600);
    final eta = Duration(seconds: seconds.round());
    final start = (startMeters ?? meters);
    final denominator = start - arrivalRadius;
    final rawProgress = denominator <= 1 ? 1.0 : 1 - (meters - arrivalRadius) / denominator;
    return TravelEstimate(
      traveller: traveller,
      origin: origin,
      meters: meters,
      accuracy: location.accuracy,
      eta: eta,
      arrivalAt: receivedAt.add(eta),
      progress: rawProgress.clamp(0.0, 1.0),
      now: now,
      receivedAt: receivedAt,
      arrivalRadius: arrivalRadius,
      startMeters: start,
    );
  }

  static String compassLabel(double bearing) {
    const labels = ['north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'];
    final index = ((bearing % 360) / 45).round() % 8;
    return labels[index];
  }
}
