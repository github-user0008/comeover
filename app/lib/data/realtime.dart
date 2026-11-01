import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/config.dart';
import '../models/member.dart';

enum RelayStatus { idle, connecting, connected, reconnecting, offline }

extension RelayStatusLabel on RelayStatus {
  String get label => switch (this) {
    RelayStatus.idle => 'Not connected',
    RelayStatus.connecting => 'Connecting',
    RelayStatus.connected => 'Live',
    RelayStatus.reconnecting => 'Reconnecting',
    RelayStatus.offline => 'Offline',
  };

  bool get isLive => this == RelayStatus.connected;
}

class RealtimeClient {
  RealtimeClient({
    required this.config,
    required this.roomId,
    required this.memberId,
    required this.token,
    required this.onSnapshot,
    required this.onMemberJoined,
    required this.onMemberLocation,
    required this.onMemberPresence,
    required this.onMemberLeft,
    required this.onSettings,
    required this.onEnded,
    required this.onStatus,
    required this.onError,
  });

  final AppConfig config;
  final String roomId;
  final String memberId;
  final String token;

  final void Function(RoomModel room, List<Member> members, Member? me)
  onSnapshot;
  final void Function(Member member) onMemberJoined;
  final void Function(String memberId, MemberLocation location)
  onMemberLocation;
  final void Function(String memberId, bool online) onMemberPresence;
  final void Function(String memberId) onMemberLeft;
  final void Function(RoomSettings settings) onSettings;
  final void Function(String reason) onEnded;
  final void Function(RelayStatus status) onStatus;
  final void Function(String message) onError;

  io.Socket? _socket;
  RelayStatus _status = RelayStatus.idle;
  bool _disposed = false;
  MemberLocation? _pendingLocation;

  RelayStatus get status => _status;

  void connect() {
    if (_disposed) return;
    final socket = io.io(
      config.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'roomId': roomId, 'memberId': memberId, 'token': token})
          .enableReconnection()
          .setReconnectionAttempts(30)
          .setReconnectionDelay(800)
          .setReconnectionDelayMax(5000)
          .build(),
    );
    _socket = socket;

    _setStatus(RelayStatus.connecting);

    socket.onConnect((_) {
      if (_disposed) return;
      _setStatus(RelayStatus.connected);
      socket.emit('room:sync');
      _flushPending();
    });

    socket.onReconnect((_) {
      if (_disposed) return;
      _setStatus(RelayStatus.connected);
      socket.emit('room:sync');
      _flushPending();
    });

    socket.onReconnectAttempt((_) {
      if (_disposed) return;
      _setStatus(RelayStatus.reconnecting);
    });

    socket.onDisconnect((_) {
      if (_disposed) return;
      _setStatus(RelayStatus.offline);
    });

    socket.onConnectError((_) {
      if (_disposed) return;
      _setStatus(RelayStatus.offline);
      onError("Can't reach the relay.");
    });

    socket.on('room:snapshot', (data) {
      if (_disposed) return;
      final map = _map(data);
      final room = RoomModel.fromJson(_map(map['room']));
      final members = _list(map['members']);
      final me = map['you'] == null ? null : Member.fromJson(_map(map['you']));
      onSnapshot(room, members, me);
    });

    socket.on('member:joined', (data) {
      if (_disposed) return;
      onMemberJoined(Member.fromJson(_map(data)));
    });

    socket.on('member:location', (data) {
      if (_disposed) return;
      final map = _map(data);
      final id = map['memberId']?.toString() ?? '';
      final raw = map['location'];
      if (id.isEmpty || raw is! Map) return;
      onMemberLocation(
        id,
        MemberLocation.fromJson(
          raw.cast<String, dynamic>(),
          receivedAt: DateTime.now(),
        ),
      );
    });

    socket.on('member:online', (data) {
      if (_disposed) return;
      final map = _map(data);
      final id = map['memberId']?.toString();
      if (id == null) return;
      onMemberPresence(id, map['online'] == true);
    });

    socket.on('member:left', (data) {
      if (_disposed) return;
      final id = _map(data)['memberId']?.toString();
      if (id != null) onMemberLeft(id);
    });

    socket.on('room:settings', (data) {
      if (_disposed) return;
      onSettings(RoomSettings.fromJson(_map(data)));
    });

    socket.on('room:ended', (data) {
      if (_disposed) return;
      onEnded(_map(data)['reason']?.toString() ?? 'ended');
    });

    socket.on('room:error', (data) {
      if (_disposed) return;
      onError(_map(data)['error']?.toString() ?? 'The room closed.');
    });

    socket.connect();
  }

  void requestSync() => _socket?.emit('room:sync');

  void sendLocation(MemberLocation location) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      _pendingLocation = location;
      return;
    }
    _pendingLocation = null;
    _emitLocation(location);
  }

  void _flushPending() {
    final pending = _pendingLocation;
    if (pending == null) return;
    _pendingLocation = null;
    _emitLocation(pending);
  }

  void _emitLocation(MemberLocation location) {
    _socket?.emit('location:update', {
      'lat': location.point.latitude,
      'lng': location.point.longitude,
      'accuracy': location.accuracy,
      'heading': location.heading,
      'speed': location.speed,
      'battery': location.battery,
    });
  }

  void _setStatus(RelayStatus next) {
    if (_status == next) return;
    _status = next;
    onStatus(next);
  }

  void dispose() {
    _disposed = true;
    final socket = _socket;
    _socket = null;
    socket?.offAny();
    socket?.dispose();
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

  static List<Member> _list(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Member.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }
}
