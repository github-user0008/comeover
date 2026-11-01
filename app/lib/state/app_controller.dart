import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/device.dart';
import '../core/format.dart';
import '../core/geo.dart';
import '../data/api.dart';
import '../data/location_service.dart';
import '../data/prefs.dart';
import '../data/realtime.dart';
import '../models/member.dart';
import '../models/travel_estimate.dart';

enum AppStage { booting, welcome, home, joining, hosting, live, ended }

typedef RealtimeFactory = RealtimeClient Function({
  required AppConfig config,
  required String roomId,
  required String memberId,
  required String token,
  required void Function(RoomModel room, List<Member> members, Member? me)
  onSnapshot,
  required void Function(Member member) onMemberJoined,
  required void Function(String memberId, MemberLocation location)
  onMemberLocation,
  required void Function(String memberId, bool online) onMemberPresence,
  required void Function(String memberId) onMemberLeft,
  required void Function(RoomSettings settings) onSettings,
  required void Function(String reason) onEnded,
  required void Function(RelayStatus status) onStatus,
  required void Function(String message) onError,
});

class AppController extends ChangeNotifier {
  AppController({
    required this.baseConfig,
    required this.prefs,
    RealtimeFactory? realtimeFactory,
  }) : _realtimeFactory = realtimeFactory ?? _defaultRealtimeFactory,
       _config = baseConfig;

  final AppConfig baseConfig;
  final Prefs prefs;
  final RealtimeFactory _realtimeFactory;

  AppConfig _config;
  AppConfig get config => _config;

  late ComeOverApi _api = ComeOverApi(config: _config);
  late LocationService _location = LocationService(config: _config);

  AppStage stage = AppStage.booting;
  AppProfile profile = const AppProfile();
  UnitSystem units = UnitSystem.metric;
  ThemeMode themeMode = ThemeMode.dark;
  bool reduceGlass = false;
  bool reduceMotion = false;
  bool liveStatusEnabled = true;
  bool? forceTv;
  bool isTelevision = false;
  String? serverOverride;

  RoomModel? room;
  Member? me;
  List<Member> members = const [];
  String? focusedMemberId;
  RelayStatus relayStatus = RelayStatus.idle;
  String? errorMessage;
  String? notice;
  bool busy = false;
  bool sharingPaused = false;
  bool approximateLocal = false;
  bool locationUnavailable = false;
  bool locationDeniedForever = false;
  LatLng? meetingPoint;
  String pendingJoinCode = '';
  String? endedReason;
  DateTime now = DateTime.now();

  LocationFix? _myFix;
  Membership? _session;
  RealtimeClient? _relay;
  StreamSubscription<LocationFix>? _watch;
  Timer? _ticker;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, double> _routeStarts = {};
  final Set<String> _arrivalsSeen = {};

  bool get isHost => me?.isHost ?? false;
  bool get isLive => stage == AppStage.live;
  bool get hasRoom => room != null;
  String get roomCode => room?.code ?? '';
  LatLng? get myPoint => me?.location?.point ?? _myFix?.point;

  /// Where distances are measured from. On a TV (no GPS) we fall back to the
  /// host's shared position so the big screen still shows useful ETAs.
  Member? get originMember {
    final self = me;
    if (self?.location != null) return self;
    for (final member in members) {
      if (member.isHost && member.location != null) return member;
    }
    return null;
  }

  LatLng? get originPoint => originMember?.location?.point ?? myPoint;

  bool get viewingFromHost => me?.location == null && originMember != null;
  String get originLabel =>
      viewingFromHost ? (originMember?.name ?? 'host') : 'you';
  bool get sharingLocation => !sharingPaused && _myFix != null;

  List<Member> get others {
    final selfId = me?.id;
    final list = members.where((m) => m.id != selfId).toList();
    list.sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      if (a.hasLocation != b.hasLocation) return a.hasLocation ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  List<Member> get trackable => others.where((m) => m.canTrack).toList();

  Member? get trackedMember {
    final candidates = trackable;
    if (candidates.isEmpty) return null;
    final originId = originMember?.id;
    final explicit = focusedMemberId;
    if (explicit != null) {
      for (final member in candidates) {
        if (member.id == explicit) return member;
      }
    }
    // On a phone the host is the natural person to watch. On a TV without GPS
    // the origin is already the host, so pick a moving guest instead.
    if (!isHost) {
      for (final member in candidates) {
        if (member.isHost && member.id != originId) return member;
      }
    }
    for (final member in candidates) {
      if (member.id != originId) return member;
    }
    return null;
  }

  TravelEstimate? get estimate {
    final traveller = trackedMember;
    final origin = originPoint;
    if (traveller == null || traveller.location == null || origin == null) {
      return null;
    }
    if (traveller.id == originMember?.id) return null;
    final receivedAt = traveller.receivedAt ?? now;
    final start = _routeStarts.putIfAbsent(
      traveller.id,
      () => distanceMeters(origin, traveller.location!.point),
    );
    return TravelEstimate.between(
      traveller: traveller,
      origin: origin,
      arrivalRadius: room?.settings.arrivalRadius ?? 40,
      now: now,
      receivedAt: receivedAt,
      startMeters: start,
    );
  }

  bool get arrivalCelebration {
    final value = estimate;
    if (value == null || !value.arrived) return false;
    return !_arrivalsSeen.contains(value.traveller.id);
  }

  String get inviteLink => _config.inviteLink(roomCode);

  void dismissArrival() {
    final traveller = estimate?.traveller;
    if (traveller != null) _arrivalsSeen.add(traveller.id);
    notifyListeners();
  }

  /* ------------------------------------------------------------- lifecycle */

  Future<void> bootstrap() async {
    profile = prefs.profile;
    units = prefs.units;
    themeMode = prefs.themeMode;
    reduceGlass = prefs.reduceGlass;
    reduceMotion = prefs.reduceMotion;
    liveStatusEnabled = prefs.liveStatusEnabled;
    forceTv = prefs.forceTv;
    isTelevision = await detectTelevision();
    serverOverride = prefs.serverOverride;
    if (serverOverride != null && serverOverride!.isNotEmpty) {
      _config = baseConfig.copyWith(
        serverUrl: serverOverride,
        publicUrl: serverOverride,
      );
      _reconfigureClients();
    }

    final deep = _deepLinkCode();
    if (deep != null) pendingJoinCode = deep;

    final stored = prefs.session;
    if (stored != null && !stored.isExpired) {
      await _resume(stored);
      if (stage == AppStage.live) {
        _startTicker();
        notifyListeners();
        return;
      }
    }

    if (!profile.isComplete) {
      stage = AppStage.welcome;
    } else if (pendingJoinCode.isNotEmpty) {
      stage = AppStage.joining;
    } else {
      stage = AppStage.home;
    }
    notifyListeners();
  }

  void _reconfigureClients() {
    _relay?.dispose();
    _relay = null;
  }

  String? _deepLinkCode() => AppConfig.inviteCodeFromUri(Uri.base);

  /// Called for native (Android/iOS) links and web deep links.
  void handleDeepLink(Uri uri) {
    final code = AppConfig.inviteCodeFromUri(uri);
    if (code == null) return;
    if (stage == AppStage.live || stage == AppStage.hosting) {
      if (code == roomCode) return;
      pendingJoinCode = code;
      notice = 'Finish this room first, then join $code.';
      notifyListeners();
      return;
    }
    pendingJoinCode = code;
    if (!profile.isComplete) {
      stage = AppStage.welcome;
    } else {
      stage = AppStage.joining;
    }
    notifyListeners();
  }

  Future<void> _resume(StoredSession stored) async {
    busy = true;
    try {
      final preview = await _api.peek(stored.code);
      if (preview.room.ended) {
        await prefs.saveSession(null);
        return;
      }
      final found = preview.members
          .where((m) => m.id == stored.memberId)
          .toList();
      if (found.isEmpty) {
        await prefs.saveSession(null);
        return;
      }
      room = preview.room;
      members = preview.members;
      me = found.first;
      _session = Membership(
        roomId: preview.room.id,
        code: preview.room.code,
        memberId: found.first.id,
        token: stored.token,
        role: stored.role,
      );
      stage = AppStage.live;
      _routeStarts.clear();
      _connect();
      _startWatchIfPossible();
    } catch (_) {
      await prefs.saveSession(null);
    } finally {
      busy = false;
    }
  }

  Future<void> updateProfile({
    required String name,
    required String avatar,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    profile = profile.copyWith(name: clean, avatar: avatar);
    await prefs.saveProfile(profile);
    notifyListeners();
  }

  Future<void> clearRecentRooms() async {
    await prefs.clearRecent();
    notifyListeners();
  }

  void showNotice(String message) {
    notice = message;
    notifyListeners();
  }

  Future<bool> completeWelcome(String name, String avatar) async {
    final clean = name.trim();
    if (clean.isEmpty) return false;
    profile = profile.copyWith(name: clean, avatar: avatar);
    await prefs.saveProfile(profile);
    stage = pendingJoinCode.isNotEmpty ? AppStage.joining : AppStage.home;
    notifyListeners();
    return true;
  }

  void goHome() {
    stage = AppStage.home;
    notifyListeners();
  }

  void openJoin([String? code]) {
    if (code != null) pendingJoinCode = code.toUpperCase();
    stage = AppStage.joining;
    notifyListeners();
  }

  /* ------------------------------------------------------------------ room */

  Future<bool> createRoom({
    required DeviceClass device,
    LatLng? at,
    bool startDemo = false,
  }) async {
    if (busy) return false;
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      LocationFix? fix;
      if (at != null) {
        fix = LocationFix(point: at, accuracy: 25, timestamp: DateTime.now());
      } else if (device == DeviceClass.tv) {
        throw const ApiException(
          'Pick a meeting point first — TVs rarely have GPS.',
        );
      } else {
        fix = await _acquireFix();
      }

      final session = await _api.createRoom(
        name: profile.name,
        avatar: profile.avatar,
        device: _deviceName(device),
        location: fix?.point,
        accuracy: fix?.accuracy,
      );
      await _adopt(session, role: 'host');
      stage = AppStage.hosting;
      _routeStarts.clear();
      if (fix != null) {
        _myFix = fix;
        _applyFix(fix, forceSend: true);
        _startWatch();
      } else {
        locationUnavailable = true;
      }
      if (startDemo) await startDemoTraveller();
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (error) {
      errorMessage = 'Could not start the room. $error';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> joinRoom(String rawCode, {required DeviceClass device}) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length < 4) {
      errorMessage = 'Enter the 6-character invite code.';
      notifyListeners();
      return false;
    }
    if (busy) return false;
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      LocationFix? fix;
      if (device != DeviceClass.tv) {
        fix = await _acquireFix();
      }
      final session = await _api.joinRoom(
        code: code,
        name: profile.name,
        avatar: profile.avatar,
        device: _deviceName(device),
      );
      await _adopt(session, role: 'guest');
      await prefs.rememberCode(code);
      stage = AppStage.live;
      pendingJoinCode = '';
      _routeStarts.clear();
      if (fix != null) {
        _myFix = fix;
        _applyFix(fix, forceSend: true);
        _startWatch();
      } else {
        locationUnavailable = true;
      }
      _startTicker();
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (error) {
      errorMessage = 'Could not join. $error';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<JoinPreview?> peek(String code) async {
    try {
      return await _api.peek(code.trim().toUpperCase());
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> startDemoTraveller({
    bool driving = false,
    double meters = 1400,
  }) async {
    final current = _session;
    if (current == null || !isHost) return;
    try {
      final member = await _api.startDemoTraveller(
        code: current.code,
        token: current.token,
        distanceMeters: meters,
        mode: driving ? 'drive' : 'walk',
        name: driving ? 'Maya driving' : 'Maya walking',
      );
      _upsertMember(member);
      focusedMemberId = member.id;
      if (stage == AppStage.hosting) stage = AppStage.live;
      _startTicker();
      notifyListeners();
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> _adopt(RoomSession session, {required String role}) async {
    room = session.room;
    members = session.members.isEmpty ? [session.me] : session.members;
    me =
        _firstWhereOrNull(session.members, (m) => m.id == session.me.id) ??
        session.me;
    _session = Membership(
      roomId: session.room.id,
      code: session.room.code,
      memberId: session.me.id,
      token: session.token,
      role: role,
    );
    units = prefs.units;
    await prefs.saveSession(
      StoredSession(
        roomId: session.room.id,
        code: session.room.code,
        memberId: session.me.id,
        token: session.token,
        expiresAt: session.room.expiresAt,
        role: role,
      ),
    );
    _connect();
  }

  void _connect() {
    final session = _session;
    if (session == null) return;
    _relay?.dispose();
    _relay = _realtimeFactory(
      config: _config,
      roomId: session.roomId,
      memberId: session.memberId,
      token: session.token,
      onSnapshot: _onSnapshot,
      onMemberJoined: _onMemberJoined,
      onMemberLocation: _onMemberLocation,
      onMemberPresence: _onMemberPresence,
      onMemberLeft: _onMemberLeft,
      onSettings: _onSettings,
      onEnded: _onEnded,
      onStatus: (status) {
        relayStatus = status;
        notifyListeners();
      },
      onError: (message) {
        notice = message;
        notifyListeners();
      },
    )..connect();
  }

  void _onSnapshot(RoomModel nextRoom, List<Member> nextMembers, Member? you) {
    room = nextRoom;
    final local = me;
    final mapped = nextMembers.map((member) {
      if (member.id == local?.id && local?.receivedAt != null) {
        final remoteTs = member.receivedAt;
        if (remoteTs == null || remoteTs.isBefore(local!.receivedAt!)) {
          return local!;
        }
      }
      return member;
    }).toList();
    if (mapped.isEmpty && me != null) mapped.add(me!);
    members = mapped;
    if (you != null) {
      me = _firstWhereOrNull(mapped, (m) => m.id == you.id) ?? you;
    }
    _prune();
    if (stage == AppStage.hosting && others.any((m) => m.canTrack)) {
      stage = AppStage.live;
      _startTicker();
    }
    notifyListeners();
  }

  void _onMemberJoined(Member member) {
    _upsertMember(member);
    if (stage == AppStage.hosting && member.id != me?.id) {
      stage = AppStage.live;
      _startTicker();
      notice = '${member.name} joined';
    }
    _startWatchIfPossible();
    notifyListeners();
  }

  void _onMemberLocation(String memberId, MemberLocation location) {
    if (memberId == me?.id) return;
    final index = members.indexWhere((m) => m.id == memberId);
    if (index == -1) return;
    final updated = members[index].withLocation(
      location,
      receivedAt: DateTime.now(),
      online: true,
    );
    members = [...members]..[index] = updated;
    if (focusedMemberId == null && !isHost && updated.isHost) {
      focusedMemberId = updated.id;
    }
    notifyListeners();
  }

  void _onMemberPresence(String memberId, bool online) {
    final index = members.indexWhere((m) => m.id == memberId);
    if (index == -1) return;
    members = [...members]..[index] = members[index].copyWith(online: online);
    notifyListeners();
  }

  void _onMemberLeft(String memberId) {
    members = members.where((m) => m.id != memberId).toList();
    if (focusedMemberId == memberId) focusedMemberId = null;
    _routeStarts.remove(memberId);
    notifyListeners();
  }

  void _onSettings(RoomSettings settings) {
    room = room?.copyWith(settings: settings);
    notifyListeners();
  }

  void _onEnded(String reason) {
    endedReason = switch (reason) {
      'host_ended' => 'The host closed the room.',
      'expired' => 'This room expired.',
      _ => 'The room closed.',
    };
    _stopWatch();
    _relay?.dispose();
    _relay = null;
    _ticker?.cancel();
    _ticker = null;
    stage = AppStage.ended;
    prefs.saveSession(null);
    notifyListeners();
  }

  Future<void> endRoom() async {
    final session = _session;
    if (session == null || !isHost) return;
    busy = true;
    notifyListeners();
    try {
      await _api.endRoom(code: session.code, token: session.token);
    } on ApiException catch (error) {
      errorMessage = error.message;
    } finally {
      endedReason = 'You closed the room.';
      _relay?.dispose();
      _relay = null;
      _stopWatch();
      _ticker?.cancel();
      _ticker = null;
      stage = AppStage.ended;
      await prefs.saveSession(null);
      busy = false;
      notifyListeners();
    }
  }

  Future<void> leaveRoom() async {
    final session = _session;
    if (session != null) {
      try {
        await _api.leaveRoom(
          code: session.code,
          token: session.token,
          memberId: session.memberId,
        );
      } catch (_) {
        // Best effort — a dead relay should never trap someone in a screen.
      }
    }
    _relay?.dispose();
    _relay = null;
    _stopWatch();
    _ticker?.cancel();
    _ticker = null;
    await prefs.saveSession(null);
    room = null;
    me = null;
    members = const [];
    focusedMemberId = null;
    _session = null;
    _routeStarts.clear();
    _arrivalsSeen.clear();
    endedReason = null;
    stage = AppStage.home;
    notifyListeners();
  }

  void _upsertMember(Member member) {
    final index = members.indexWhere((m) => m.id == member.id);
    if (index == -1) {
      members = [...members, member];
    } else {
      members = [...members]..[index] = member;
    }
    if (member.id == me?.id) me = member;
    if (focusedMemberId == null &&
        member.id != me?.id &&
        member.canTrack &&
        isHost) {
      focusedMemberId = member.id;
    }
  }

  void focusMember(String memberId) {
    focusedMemberId = memberId;
    _routeStarts.remove(memberId);
    notifyListeners();
  }

  /* -------------------------------------------------------------- location */

  Future<LocationFix?> _acquireFix() async {
    final result = await _location.ensureAndLocate();
    switch (result.state) {
      case LocationState.serviceDisabled:
        locationUnavailable = true;
      case LocationState.denied:
      case LocationState.deniedForever:
        locationUnavailable = true;
        locationDeniedForever = result.state == LocationState.deniedForever;
      case LocationState.unsupported:
        locationUnavailable = true;
      case LocationState.granted:
        locationUnavailable = result.fix == null;
      case LocationState.unknown:
        break;
    }
    return result.fix;
  }

  void _startWatchIfPossible() {
    if (_watch != null) return;
    if (_config.previewMode) return;
    _startWatch();
  }

  void _startWatch() {
    if (_watch != null) return;
    _location.setBackgroundUpdates(liveStatusEnabled);
    _watch = _location.watch().listen((fix) {
      if (sharingPaused) return;
      _myFix = fix;
      _applyFix(fix);
    });
  }

  void _stopWatch() {
    _watch?.cancel();
    _watch = null;
    _location.stop();
  }

  void _applyFix(LocationFix fix, {bool forceSend = false}) {
    final effective = approximateLocal ? fix.coarsened() : fix;
    final memberLocation = MemberLocation(
      point: effective.point,
      accuracy: effective.accuracy,
      heading: effective.heading,
      speed: effective.speed,
      battery: effective.battery,
      timestamp: effective.timestamp,
    );
    final current = me;
    if (current != null) {
      me = current.withLocation(memberLocation, receivedAt: DateTime.now());
      _upsertMember(me!);
    }
    final sentAt = DateTime.now();
    if (forceSend ||
        sentAt.difference(_lastSent) > const Duration(milliseconds: 900)) {
      _lastSent = sentAt;
      _relay?.sendLocation(memberLocation);
    }
    notifyListeners();
  }

  Future<void> useMeetingPoint(LatLng point) async {
    meetingPoint = point;
    final fix = LocationFix(
      point: point,
      accuracy: 30,
      timestamp: DateTime.now(),
    );
    _myFix = fix;
    _applyFix(fix, forceSend: true);
    if (locationUnavailable) locationUnavailable = false;
    notifyListeners();
  }

  /// Attempt to start sharing from this device after the user grants permission.
  Future<bool> retryLocation() async {
    final fix = await _acquireFix();
    if (fix == null) {
      notifyListeners();
      return false;
    }
    _myFix = fix;
    _applyFix(fix, forceSend: true);
    _startWatch();
    notifyListeners();
    return true;
  }

  Future<void> setSharingPaused(bool paused) async {
    sharingPaused = paused;
    if (!paused) {
      final fix = _myFix ?? await _acquireFix();
      if (fix != null) _applyFix(fix, forceSend: true);
      _startWatchIfPossible();
    }
    notifyListeners();
  }

  Future<void> setApproximateLocal(bool value) async {
    approximateLocal = value;
    final fix = _myFix;
    if (fix != null) {
      _myFix = value ? fix.coarsened() : fix;
      _applyFix(_myFix!, forceSend: true);
    }
    notifyListeners();
  }

  /* -------------------------------------------------------------- settings */

  Future<void> setUnits(UnitSystem value) async {
    units = value;
    await prefs.saveUnits(value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await prefs.saveThemeMode(mode);
    notifyListeners();
  }

  Future<void> setReduceGlass(bool value) async {
    reduceGlass = value;
    await prefs.saveReduceGlass(value);
    notifyListeners();
  }

  Future<void> setReduceMotion(bool value) async {
    reduceMotion = value;
    await prefs.saveReduceMotion(value);
    notifyListeners();
  }

  Future<void> setLiveStatusEnabled(bool value) async {
    liveStatusEnabled = value;
    await prefs.saveLiveStatusEnabled(value);
    _location.setBackgroundUpdates(value);
    if (isLive && _watch != null) {
      // Restart the stream so Android starts (or stops) its foreground
      // location service immediately instead of on the next room join.
      _stopWatch();
      _startWatch();
    }
    notifyListeners();
  }

  Future<void> setForceTv(bool? value) async {
    forceTv = value;
    await prefs.saveForceTv(value);
    notifyListeners();
  }

  Future<bool> setServerOverride(String? url) async {
    final clean = url?.trim();
    if (clean == null || clean.isEmpty) {
      serverOverride = null;
      await prefs.saveServerOverride(null);
      _config = baseConfig;
      _reconfigureClients();
      _api = ComeOverApi(config: _config);
      _location = LocationService(config: _config)
        ..setBackgroundUpdates(liveStatusEnabled);
      notifyListeners();
      return true;
    }
    final normalized = _normalizeServer(clean);
    if (normalized == null) {
      errorMessage = 'Use a full URL, like http://192.168.1.20:8787';
      notifyListeners();
      return false;
    }
    serverOverride = normalized;
    await prefs.saveServerOverride(normalized);
    _config = baseConfig.copyWith(serverUrl: normalized, publicUrl: normalized);
    _reconfigureClients();
    _api = ComeOverApi(config: _config);
    _location = LocationService(config: _config)
      ..setBackgroundUpdates(liveStatusEnabled);
    notifyListeners();
    return true;
  }

  String? _normalizeServer(String value) {
    var candidate = value.trim();
    if (!candidate.startsWith('http://') && !candidate.startsWith('https://')) {
      candidate = 'http://$candidate';
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return null;
    return candidate.endsWith('/')
        ? candidate.substring(0, candidate.length - 1)
        : candidate;
  }

  Future<bool> checkRelay() async {
    try {
      return await _api.isHealthy();
    } catch (_) {
      return false;
    }
  }

  Future<void> setPrecision({required bool approximate}) async {
    final session = _session;
    final currentRoom = room;
    if (session == null || currentRoom == null) return;
    if (!isHost) {
      await setApproximateLocal(approximate);
      return;
    }
    final settings = currentRoom.settings.copyWith(
      precision: approximate ? 'approximate' : 'exact',
    );
    room = currentRoom.copyWith(settings: settings);
    notifyListeners();
    try {
      await _api.updateSettings(
        code: session.code,
        token: session.token,
        precision: settings.precision,
      );
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> setArrivalRadius(double meters) async {
    final session = _session;
    final currentRoom = room;
    if (session == null || currentRoom == null || !isHost) return;
    final settings = currentRoom.settings.copyWith(arrivalRadius: meters);
    room = currentRoom.copyWith(settings: settings);
    notifyListeners();
    try {
      await _api.updateSettings(
        code: session.code,
        token: session.token,
        arrivalRadius: meters,
      );
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> removeMember(String memberId) async {
    final session = _session;
    if (session == null || !isHost) return;
    try {
      await _api.removeMember(
        code: session.code,
        token: session.token,
        memberId: memberId,
      );
      _onMemberLeft(memberId);
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  /* ------------------------------------------------------------------ misc */

  void _startTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
      final value = estimate;
      if (value != null &&
          value.arrived &&
          !_arrivalsSeen.contains(value.traveller.id)) {
        // Leave it un-dismissed: the live screen shows a celebration once and
        // calls dismissArrival().
      }
      notifyListeners();
    });
  }

  void _prune() {
    final liveIds = members.map((m) => m.id).toSet();
    _routeStarts.removeWhere((id, _) => !liveIds.contains(id));
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  String _deviceName(DeviceClass device) => switch (device) {
    DeviceClass.tv => 'tv',
    DeviceClass.tablet => 'tablet',
    DeviceClass.phone => 'phone',
  };

  DateTime get lastFixAt => _myFix?.timestamp ?? now;

  static T? _firstWhereOrNull<T>(Iterable<T> list, bool Function(T) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _watch?.cancel();
    _relay?.dispose();
    _api.close();
    _location.dispose();
    super.dispose();
  }
}

class Membership {
  const Membership({
    required this.roomId,
    required this.code,
    required this.memberId,
    required this.token,
    required this.role,
  });

  final String roomId;
  final String code;
  final String memberId;
  final String token;
  final String role;
}

RealtimeClient _defaultRealtimeFactory({
  required AppConfig config,
  required String roomId,
  required String memberId,
  required String token,
  required void Function(RoomModel room, List<Member> members, Member? me)
  onSnapshot,
  required void Function(Member member) onMemberJoined,
  required void Function(String memberId, MemberLocation location)
  onMemberLocation,
  required void Function(String memberId, bool online) onMemberPresence,
  required void Function(String memberId) onMemberLeft,
  required void Function(RoomSettings settings) onSettings,
  required void Function(String reason) onEnded,
  required void Function(RelayStatus status) onStatus,
  required void Function(String message) onError,
}) => RealtimeClient(
  config: config,
  roomId: roomId,
  memberId: memberId,
  token: token,
  onSnapshot: onSnapshot,
  onMemberJoined: onMemberJoined,
  onMemberLocation: onMemberLocation,
  onMemberPresence: onMemberPresence,
  onMemberLeft: onMemberLeft,
  onSettings: onSettings,
  onEnded: onEnded,
  onStatus: onStatus,
  onError: onError,
);
