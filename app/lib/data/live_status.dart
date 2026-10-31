import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../state/app_controller.dart';

/// What the native lock-screen surfaces should show right now.
///
/// One snapshot is shared by Android Live Updates and the iOS Live Activity /
/// Dynamic Island. The native side only renders it; every decision about who
/// is being tracked, how far away they are and when they arrive stays here.
class LiveStatusSnapshot {
  const LiveStatusSnapshot({
    required this.active,
    required this.phase,
    required this.title,
    required this.subtitle,
    required this.shortText,
    required this.distance,
    required this.eta,
    required this.memberName,
    required this.memberAvatar,
    required this.roomCode,
    required this.progress,
    required this.arrivalAt,
    required this.updatedAt,
  });

  const LiveStatusSnapshot.inactive()
      : active = false,
        phase = 'idle',
        title = 'ComeOver',
        subtitle = 'No room open',
        shortText = '',
        distance = '',
        eta = '',
        memberName = '',
        memberAvatar = '📍',
        roomCode = '',
        progress = 0,
        arrivalAt = null,
        updatedAt = null;

  final bool active;

  /// `idle`, `waiting`, `travelling` or `arrived`.
  final String phase;
  final String title;
  final String subtitle;

  /// Status-bar chip text: "3 min", "820 m", "Here", "Live".
  final String shortText;

  /// Human formatted distance and ETA, kept separate so native widgets can lay
  /// them out independently.
  final String distance;
  final String eta;
  final String memberName;
  final String memberAvatar;
  final String roomCode;
  final double progress;
  final DateTime? arrivalAt;
  final DateTime? updatedAt;

  bool get arrived => phase == 'arrived';

  /// Coarse identity of the content. The countdown ticks natively, so we only
  /// push when the meaningful text crosses a boundary.
  String get signature => [
        active ? 1 : 0,
        phase,
        title,
        subtitle,
        shortText,
        distance,
        (progress * 100).round(),
        arrivalAt?.millisecondsSinceEpoch ?? 0,
        roomCode,
      ].join('|');

  Map<String, Object?> toMap() => {
        'active': active,
        'phase': phase,
        'title': title,
        'subtitle': subtitle,
        'shortText': shortText,
        'distance': distance,
        'eta': eta,
        'memberName': memberName,
        'memberAvatar': memberAvatar,
        'roomCode': roomCode,
        'progress': progress.clamp(0.0, 1.0),
        'arrivalAt': arrivalAt?.millisecondsSinceEpoch,
        'updatedAt': (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
      };
}

/// Builds the lock-screen snapshot from the room controller.
LiveStatusSnapshot buildLiveStatus(AppController app) {
  final room = app.room;
  if (!app.isLive || room == null) return const LiveStatusSnapshot.inactive();

  final estimate = app.estimate;
  // `trackedMember` only returns people who have already shared a position.
  // Fall back to any other member so "waiting" can name them before their
  // first fix arrives.
  final tracked = estimate?.traveller ??
      app.trackedMember ??
      (app.others.isEmpty ? null : app.others.first);
  final units = app.units;

  if (estimate != null) {
    final name = firstName(estimate.traveller.name);
    if (estimate.arrived) {
      return LiveStatusSnapshot(
        active: true,
        phase: 'arrived',
        title: '$name is here',
        subtitle: 'Open the door — the countdown finished.',
        shortText: 'Here',
        distance: formatDistance(estimate.meters, units),
        eta: formatDuration(estimate.eta, precise: false),
        memberName: estimate.traveller.name,
        memberAvatar: estimate.traveller.avatar,
        roomCode: room.code,
        progress: 1,
        arrivalAt: null,
        updatedAt: app.now,
      );
    }
    final distance = formatDistance(estimate.meters, units);
    final eta = formatDuration(estimate.eta, precise: false);
    final countdown = formatDuration(estimate.countdown, precise: false);
    return LiveStatusSnapshot(
      active: true,
      phase: 'travelling',
      title: '$name is $distance away',
      subtitle: '$eta · ${formatArrival(estimate.arrivalAt)}',
      shortText: countdown,
      distance: distance,
      eta: eta,
      memberName: estimate.traveller.name,
      memberAvatar: estimate.traveller.avatar,
      roomCode: room.code,
      progress: estimate.progress,
      arrivalAt: estimate.arrivalAt,
      updatedAt: app.now,
    );
  }

  if (tracked != null) {
    final name = firstName(tracked.name);
    return LiveStatusSnapshot(
      active: true,
      phase: 'waiting',
      title: 'Waiting for $name',
      subtitle: 'Their location will appear here as soon as they share it.',
      shortText: 'Waiting',
      distance: '',
      eta: '',
      memberName: tracked.name,
      memberAvatar: tracked.avatar,
      roomCode: room.code,
      progress: 0,
      arrivalAt: null,
      updatedAt: app.now,
    );
  }

  return LiveStatusSnapshot(
    active: true,
    phase: 'waiting',
    title: app.isHost ? 'Room ${room.code} is open' : 'You are in room ${room.code}',
    subtitle: app.isHost
        ? 'Share the invite link so someone can come over.'
        : 'Waiting for the host to share their location.',
    shortText: 'Live',
    distance: '',
    eta: '',
    memberName: '',
    memberAvatar: '📍',
    roomCode: room.code,
    progress: 0,
    arrivalAt: null,
    updatedAt: app.now,
  );
}

String firstName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.isEmpty ? 'They' : parts.first;
}

/// Thin wrapper around the native `dev.comeover/live_status` channel.
class LiveStatusBridge {
  static const _channel = MethodChannel('dev.comeover/live_status');

  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> start(LiveStatusSnapshot snapshot) async {
    try {
      return await _channel.invokeMethod<bool>('start', snapshot.toMap()) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> update(LiveStatusSnapshot snapshot) async {
    try {
      await _channel.invokeMethod<void>('update', snapshot.toMap());
    } catch (_) {
      // A live activity may have expired while the app was suspended.
    }
  }

  Future<void> end() async {
    try {
      await _channel.invokeMethod<void>('end');
    } catch (_) {}
  }

  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {}
  }

  /// iOS only: asks to upgrade location access to "Always" so the countdown
  /// keeps moving while the phone is locked.
  Future<void> requestBackgroundLocation() async {
    try {
      await _channel.invokeMethod<void>('requestBackgroundLocation');
    } catch (_) {}
  }
}

/// Keeps native live status in sync with [AppController] without flooding the
/// platform channel once per ticker second.
class LiveStatusCoordinator {
  LiveStatusCoordinator({LiveStatusBridge? bridge}) : _bridge = bridge ?? LiveStatusBridge();

  static final instance = LiveStatusCoordinator();

  final LiveStatusBridge _bridge;

  bool _running = false;
  bool _permissionAsked = false;
  bool _permissionWarned = false;
  bool _backgroundRequested = false;
  bool _inflight = false;
  bool _unsupported = false;
  String? _lastSignature;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastStartAttempt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> sync(AppController app, {bool force = false}) async {
    if (app.liveStatusEnabled == false) {
      await _stop();
      return;
    }

    final snapshot = buildLiveStatus(app);
    if (!snapshot.active) {
      await _stop();
      return;
    }
    if (_unsupported) return;
    if (force) _lastSignature = null;

    // Cheap check first: the ticker fires every second but most frames do not
    // change the meaningful lock-screen text.
    final signature = snapshot.signature;
    final now = DateTime.now();
    final due = signature != _lastSignature || now.difference(_lastPush) >= const Duration(seconds: 20);
    if (!due) return;
    if (_inflight) return;
    _inflight = true;
    try {
      if (!await _bridge.isSupported()) {
        _unsupported = true;
        return;
      }
      if (!await _ensurePermission(app)) return;

      if (_running) {
        await _bridge.update(snapshot);
      } else {
        if (now.difference(_lastStartAttempt) < const Duration(seconds: 15)) return;
        _lastStartAttempt = now;
        if (!_backgroundRequested && defaultTargetPlatform == TargetPlatform.iOS) {
          _backgroundRequested = true;
          await _bridge.requestBackgroundLocation();
        }
        final started = await _bridge.start(snapshot);
        if (!started) return;
        _running = true;
      }
      _lastSignature = signature;
      _lastPush = now;
    } finally {
      _inflight = false;
    }
  }

  Future<void> _stop() async {
    if (!_running) return;
    _running = false;
    _lastSignature = null;
    await _bridge.end();
  }

  Future<bool> _ensurePermission(AppController app) async {
    if (await _bridge.hasPermission()) return true;
    if (_permissionAsked) {
      if (!_permissionWarned) {
        _permissionWarned = true;
        app.showNotice(_permissionMessage);
      }
      return false;
    }
    _permissionAsked = true;
    final granted = await _bridge.requestPermission();
    if (!granted && !_permissionWarned) {
      _permissionWarned = true;
      app.showNotice(_permissionMessage);
    }
    return granted;
  }

  String get _permissionMessage {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Live Activities are off, so the countdown cannot be pinned to your Lock Screen. Turn them on in Settings.';
    }
    return 'Notifications are off, so the live status cannot be pinned to your lock screen.';
  }

  /// Called when the app is removed. Ending here prevents an orphaned Live
  /// Activity after the user force-quits.
  Future<void> shutdown() => _stop();
}
