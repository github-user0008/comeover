import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/travel_estimate.dart';
import '../state/app_controller.dart';

/// Host-side stale-position alerts as *local* notifications.
///
/// Deliberately not a separate "admin" app: the moment any host opens a live
/// room we ask for notification permission once (the ask flag lives in
/// prefs), and from then on every staleness episode of the tracked traveller
/// raises one notification — reset as soon as positions flow again.
/// Everything is best-effort: MethodChannel calls that aren't available (web,
/// TV builds, unit tests, ungranted permission) are swallowed, because a
/// silent alert not firing must never break the room.
class StaleAlerter {
  StaleAlerter._();

  static final StaleAlerter instance = StaleAlerter._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initTried = false;
  bool _initialized = false;
  bool _asking = false;
  // Per-traveller staleness bookkeeping so each episode alerts exactly once.
  final Set<String> _alerted = <String>{};

  Future<void> _ensureInitialized() async {
    if (_initTried) return;
    _initTried = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_live_status'),
        ),
      );
      _initialized = true;
    } catch (_) {
      // No plugin platform (tests, unsupported embedder) — stay silent.
    }
  }

  void reset() {
    _alerted.clear();
  }

  /// Called once when a host enters a live room. Requests the Android 13+
  /// POST_NOTIFICATIONS runtime permission the first time only.
  Future<void> ensurePermission(AppController app) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    if (app.prefs.staleNotifyAsked || _asking) return;
    _asking = true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await app.prefs.saveStaleNotifyAsked(true);
    } catch (_) {
      // Never let a permission probe crash the room.
      try {
        await app.prefs.saveStaleNotifyAsked(true);
      } catch (_) {}
    } finally {
      _asking = false;
    }
  }

  /// Ticked roughly once a second from the app ticker; guards internally and
  /// early-returns when there is nothing to do.
  Future<void> evaluate(AppController app) async {
    if (kIsWeb) return;
    if (app.stage != AppStage.live || !app.isHost) return;
    final TravelEstimate? estimate = app.estimate;
    if (estimate == null) {
      _alerted.clear();
      return;
    }
    await _ensureInitialized();
    if (!_initialized) return;
    if (!app.prefs.staleNotifyAsked) return;

    final id = estimate.traveller.id;
    if (!estimate.stale) {
      _alerted.remove(id);
      return;
    }
    if (!_alerted.add(id)) return;

    final name = estimate.traveller.name.isEmpty
        ? 'Your traveller'
        : estimate.traveller.name;
    final age = estimate.staleFor;
    final ageText = age.inMinutes >= 1
        ? '${age.inMinutes} min'
        : '${age.inSeconds} s';
    try {
      await _plugin.show(
        id: id.hashCode & 0x7fffffff,
        title: 'Position went stale',
        body:
            '$name hasn\'t updated their location for $ageText — their phone '
            'may have lost tracking. They can reopen the app to resume.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'stale_alerts',
            'Trip alerts',
            channelDescription:
                'Alerts when someone\'s live position stops updating.',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            autoCancel: true,
          ),
        ),
      );
    } catch (_) {
      // Permission revoked mid-trip or a dead platform channel: drop it.
      _alerted.remove(id);
    }
  }
}
