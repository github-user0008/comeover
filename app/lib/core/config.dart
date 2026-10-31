import 'package:flutter/foundation.dart';

/// Everything the app needs to know about where it is running and how it
/// should talk to the relay.
class AppConfig {
  const AppConfig({
    required this.serverUrl,
    required this.publicUrl,
    required this.isWeb,
    required this.isAndroid,
    required this.isIOS,
    required this.demoLocation,
    required this.previewMode,
  });

  /// Realtime relay base URL (Socket.IO + REST).
  final String serverUrl;

  /// Base URL used inside invite links shown to other people.
  final String publicUrl;
  final bool isWeb;
  final bool isAndroid;
  final bool isIOS;

  /// Optional fixed location, handy for emulators and TVs without GPS.
  final ({double lat, double lng})? demoLocation;

  /// Skip permission prompts and animate simulated data (used for screenshots).
  final bool previewMode;

  /// Pulls an invite code out of any of the link shapes we hand out:
  /// `comeover://join/ABC123`, `https://host/j/ABC123`, `?code=ABC123` and
  /// web-hash `#join/ABC123`.
  static String? inviteCodeFromUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final segments = uri.pathSegments;
    String? raw;
    if (scheme == 'comeover' || scheme == 'comeover-dev') {
      if (uri.host.toLowerCase() == 'join') {
        raw = segments.isEmpty ? null : segments.first;
      } else if (segments.length >= 2 && segments.first == 'join') {
        raw = segments[1];
      } else if (segments.isNotEmpty) {
        raw = segments.last;
      }
    } else if (segments.length >= 2 && segments[segments.length - 2] == 'j') {
      raw = segments.last;
    } else {
      raw = uri.queryParameters['code'] ?? uri.queryParameters['invite'];
      if (raw == null && uri.fragment.startsWith('join/')) {
        raw = uri.fragment.substring(5);
      }
      if (raw == null && uri.fragment.startsWith('/join/')) {
        raw = uri.fragment.substring(6);
      }
    }
    final code = raw?.trim().toUpperCase();
    if (code == null || !RegExp(r'^[A-Z0-9]{4,8}$').hasMatch(code)) return null;
    return code;
  }

  static AppConfig load() {
    const serverOverride = String.fromEnvironment('COMEOVER_SERVER');
    const publicOverride = String.fromEnvironment('COMEOVER_PUBLIC_URL');
    const demoRaw = String.fromEnvironment('COMEOVER_DEMO_LOCATION');
    const preview = bool.fromEnvironment('COMEOVER_PREVIEW');

    final fallback = _defaultServer();
    final server = _trimSlash(serverOverride.isNotEmpty ? serverOverride : fallback);
    final public = _trimSlash(
      publicOverride.isNotEmpty
          ? publicOverride
          : (kIsWeb ? server : server),
    );

    ({double lat, double lng})? demo;
    if (demoRaw.contains(',')) {
      final parts = demoRaw.split(',');
      final lat = double.tryParse(parts.first.trim());
      final lng = double.tryParse(parts.last.trim());
      if (lat != null && lng != null) demo = (lat: lat, lng: lng);
    }

    return AppConfig(
      serverUrl: server,
      publicUrl: public,
      isWeb: kIsWeb,
      isAndroid: defaultTargetPlatform == TargetPlatform.android,
      isIOS: defaultTargetPlatform == TargetPlatform.iOS,
      demoLocation: demo,
      previewMode: preview,
    );
  }

  static String _defaultServer() {
    const env = String.fromEnvironment('COMEOVER_SERVER');
    if (env.isNotEmpty) return env;
    if (kIsWeb) {
      // The dashboard is usually served from the same origin as the relay.
      final origin = Uri.base.origin;
      if (origin != 'null' && origin.isNotEmpty && !origin.startsWith('file:')) {
        return origin;
      }
      return 'http://localhost:8787';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator loopback. Physical devices override this in Settings.
      return 'http://10.0.2.2:8787';
    }
    return 'http://localhost:8787';
  }

  static String _trimSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  AppConfig copyWith({String? serverUrl, String? publicUrl}) => AppConfig(
        serverUrl: serverUrl ?? this.serverUrl,
        publicUrl: publicUrl ?? this.publicUrl,
        isWeb: isWeb,
        isAndroid: isAndroid,
        isIOS: isIOS,
        demoLocation: demoLocation,
        previewMode: previewMode,
      );

  String inviteLink(String code) => '$publicUrl/j/$code';
}
