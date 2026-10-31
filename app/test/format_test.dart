import 'package:comeover/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDistance', () {
    test('metric switches from metres to kilometres', () {
      expect(formatDistance(0, UnitSystem.metric), '0 m');
      expect(formatDistance(820, UnitSystem.metric), '820 m');
      expect(formatDistance(1234, UnitSystem.metric), '1.2 km');
      expect(formatDistance(123400, UnitSystem.metric, compact: true), '123 km');
    });

    test('imperial uses feet and miles', () {
      expect(formatDistance(30, UnitSystem.imperial), '98 ft');
      expect(formatDistance(1609.344, UnitSystem.imperial), '1.0 mi');
      expect(formatDistance(32186.88, UnitSystem.imperial), '20 mi');
    });

    test('handles non-finite values', () {
      expect(formatDistance(double.nan, UnitSystem.metric), '—');
    });
  });

  group('formatDuration', () {
    test('seconds, minutes and hours', () {
      expect(formatDuration(Duration.zero), 'now');
      expect(formatDuration(const Duration(seconds: 42)), '42 s');
      expect(formatDuration(const Duration(minutes: 3, seconds: 12)), '3 min 12 s');
      expect(formatDuration(const Duration(minutes: 12, seconds: 50)), '12 min');
      expect(formatDuration(const Duration(hours: 1, minutes: 4)), '1 hr 4 min');
      expect(formatDuration(const Duration(seconds: 42), precise: false), 'under a minute');
    });
  });

  test('formatCountdown pads seconds and handles hours', () {
    expect(formatCountdown(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatCountdown(const Duration(seconds: -4)), '0:00');
  });

  test('clock and ago helpers are readable', () {
    expect(formatClock(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
    expect(formatClock(DateTime(2026, 1, 1, 13, 9)), '1:09 PM');
    expect(formatAgo(const Duration(seconds: 2)), 'just now');
    expect(formatAgo(const Duration(seconds: 30)), '30s ago');
    expect(formatAgo(const Duration(minutes: 5)), '5m ago');
    expect(formatAgo(const Duration(hours: 2)), '2h ago');
  });

  test('motion labels and initials', () {
    expect(motionLabel(null), 'moving');
    expect(motionLabel(0), 'stopped');
    expect(motionLabel(1.4), 'walking');
    expect(motionLabel(4), 'cycling');
    expect(motionLabel(12), 'driving');
    expect(initialsFor('Maya Rao'), 'MR');
    expect(initialsFor('sam'), 'S');
    expect(initialsFor('   '), '?');
    expect(plural(1, 'person', 'people'), 'person');
    expect(plural(3, 'person', 'people'), 'people');
    expect(plural(3, 'guest'), 'guests');
  });
}
