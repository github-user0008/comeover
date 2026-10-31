import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../models/member.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code = 'error', this.status = 0});

  final String message;
  final String code;
  final int status;

  bool get isNotFound => status == 404;
  bool get isGone => status == 410;
  bool get isUnauthorized => status == 401 || status == 403;

  @override
  String toString() => message;
}

class JoinPreview {
  const JoinPreview({required this.room, required this.members});

  final RoomModel room;
  final List<Member> members;

  bool get isFull => members.length >= 8;
}

class ComeOverApi {
  ComeOverApi({required this.config, http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  final AppConfig config;
  final http.Client _client;
  final Duration timeout;

  Uri _uri(String path) => Uri.parse('${config.serverUrl}$path');

  Future<RoomSession> createRoom({
    required String name,
    required String avatar,
    required String device,
    required LatLng? location,
    double? accuracy,
  }) async {
    final body = await _post('/api/rooms', {
      'name': name,
      'avatar': avatar,
      'device': device,
      if (location != null)
        'location': {
          'lat': location.latitude,
          'lng': location.longitude,
          'accuracy': accuracy ?? 25,
        },
    });
    return _sessionFrom(body);
  }

  Future<RoomSession> joinRoom({
    required String code,
    required String name,
    required String avatar,
    required String device,
  }) async {
    final body = await _post('/api/rooms/${Uri.encodeComponent(code)}/join', {
      'name': name,
      'avatar': avatar,
      'device': device,
    });
    return _sessionFrom(body);
  }

  Future<JoinPreview> peek(String code) async {
    final body = await _get('/api/rooms/${Uri.encodeComponent(code)}');
    final room = RoomModel.fromJson(_map(body['room']));
    final members = _members(body['members']);
    return JoinPreview(room: room, members: members);
  }

  Future<void> updateSettings({
    required String code,
    required String token,
    String? precision,
    double? arrivalRadius,
    String? units,
  }) async {
    await _post(
      '/api/rooms/${Uri.encodeComponent(code)}/settings',
      {
        'precision': ?precision,
        'arrivalRadius': ?arrivalRadius,
        'units': ?units,
      },
      token: token,
    );
  }

  Future<Member> startDemoTraveller({
    required String code,
    required String token,
    double distanceMeters = 1400,
    String mode = 'walk',
    String? name,
  }) async {
    final body = await _post(
      '/api/rooms/${Uri.encodeComponent(code)}/demo',
      {
        'distanceM': distanceMeters,
        'mode': mode,
        'name': ?name,
      },
      token: token,
    );
    return Member.fromJson(_map(body['member']));
  }

  Future<void> removeMember({
    required String code,
    required String token,
    required String memberId,
  }) async {
    await _delete('/api/rooms/${Uri.encodeComponent(code)}/members/${Uri.encodeComponent(memberId)}', token: token);
  }

  Future<void> endRoom({required String code, required String token}) async {
    await _post('/api/rooms/${Uri.encodeComponent(code)}/end', {}, token: token);
  }

  Future<void> leaveRoom({
    required String code,
    required String token,
    required String memberId,
  }) async {
    await _delete(
      '/api/rooms/${Uri.encodeComponent(code)}/members/${Uri.encodeComponent(memberId)}',
      token: token,
    );
  }

  Future<bool> isHealthy() async {
    try {
      final body = await _get('/healthz');
      return body['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _client.get(_uri(path)).timeout(timeout);
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('The relay took too long to answer.', code: 'timeout');
    } on http.ClientException {
      throw const ApiException("Can't reach the relay. Check the server address.", code: 'network');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    try {
      final response = await _client
          .post(
            _uri(path),
            headers: {
              'content-type': 'application/json',
              'x-member-token': ?token,
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('The relay took too long to answer.', code: 'timeout');
    } on http.ClientException {
      throw const ApiException("Can't reach the relay. Check the server address.", code: 'network');
    }
  }

  Future<Map<String, dynamic>> _delete(String path, {String? token}) async {
    try {
      final response = await _client.delete(
        _uri(path),
        headers: {'x-member-token': ?token},
      ).timeout(timeout);
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('The relay took too long to answer.', code: 'timeout');
    } on http.ClientException {
      throw const ApiException("Can't reach the relay. Check the server address.", code: 'network');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = const {};
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map) body = parsed.cast<String, dynamic>();
    } catch (_) {
      // Non-JSON body (999 from a proxy, empty response, etc.)
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        (body['error'] as String?) ?? 'The relay returned ${response.statusCode}.',
        code: (body['code'] as String?) ?? 'http',
        status: response.statusCode,
      );
    }
    return body;
  }

  RoomSession _sessionFrom(Map<String, dynamic> body) {
    final room = RoomModel.fromJson(_map(body['room']));
    final me = Member.fromJson(_map(body['member']));
    final members = _members(body['members']);
    return RoomSession(
      room: room,
      me: me,
      members: members.isEmpty ? [me] : members,
      token: body['token']?.toString() ?? '',
    );
  }

  List<Member> _members(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Member.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
}
