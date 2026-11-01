enum UnitSystem { metric, imperial }

UnitSystem unitSystemFrom(String? value) =>
    value == 'imperial' ? UnitSystem.imperial : UnitSystem.metric;

String unitSystemName(UnitSystem units) =>
    units == UnitSystem.imperial ? 'imperial' : 'metric';

/// "820 m", "1.2 km", "3.4 mi", "900 ft".
String formatDistance(double meters, UnitSystem units, {bool compact = false}) {
  if (!meters.isFinite) return '—';
  if (units == UnitSystem.imperial) {
    final feet = meters * 3.28084;
    if (feet < 1000) return '${feet.round()} ft';
    final miles = meters / 1609.344;
    final decimals = miles < 10 ? 1 : 0;
    return '${miles.toStringAsFixed(decimals)} mi';
  }
  if (meters < 1000) {
    final rounded = meters < 100 ? meters.round() : (meters / 5).round() * 5;
    return '$rounded m';
  }
  final km = meters / 1000;
  final decimals = km < 10 ? 1 : 0;
  if (compact && km >= 100) return '${km.round()} km';
  return '${km.toStringAsFixed(decimals)} km';
}

/// "3 min 12 s" / "1 hr 4 min" / "under a minute".
String formatDuration(Duration duration, {bool precise = true}) {
  final seconds = duration.inSeconds;
  if (seconds <= 0) return 'now';
  if (seconds < 60) return precise ? '$seconds s' : 'under a minute';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final secs = duration.inSeconds.remainder(60);
  if (hours > 0) return '$hours hr $minutes min';
  if (minutes >= 10 || !precise) return '$minutes min';
  return '$minutes min $secs s';
}

/// "3:12" style countdown for the big HUD number.
String formatCountdown(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  if (safe.inHours > 0) {
    return '${safe.inHours}:${two(safe.inMinutes.remainder(60))}:${two(safe.inSeconds.remainder(60))}';
  }
  return '${safe.inMinutes}:${two(safe.inSeconds.remainder(60))}';
}

String two(int value) => value.toString().padLeft(2, '0');

String formatClock(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = two(time.minute);
  return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
}

String formatAgo(Duration age) {
  if (age.inSeconds < 5) return 'just now';
  if (age.inSeconds < 60) return '${age.inSeconds}s ago';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';
  return '${age.inHours}h ago';
}

/// "walking pace", "driving", "paused".
String motionLabel(double? speedMetersPerSecond) {
  if (speedMetersPerSecond == null) return 'moving';
  if (speedMetersPerSecond < 0.6) return 'stopped';
  if (speedMetersPerSecond < 2.2) return 'walking';
  if (speedMetersPerSecond < 8) return 'cycling';
  return 'driving';
}

/// Wall-clock arrival estimate, e.g. "arrives 6:42 PM".
String formatArrival(DateTime time) => 'arrives ${formatClock(time)}';

String relativeTimeFromNow(DateTime time, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(time);
  return formatAgo(age.isNegative ? Duration.zero : age);
}

String initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  String first(String value) =>
      String.fromCharCode(value.runes.first).toUpperCase();
  if (parts.length == 1) return first(parts.first);
  return first(parts.first) + first(parts.last);
}

String plural(int count, String singular, [String? pluralWord]) =>
    count == 1 ? singular : (pluralWord ?? '${singular}s');
