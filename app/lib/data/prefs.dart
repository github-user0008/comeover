import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';

class AppProfile {
  const AppProfile({this.name = '', this.avatar = '🦊'});

  final String name;
  final String avatar;

  bool get isComplete => name.trim().isNotEmpty;

  AppProfile copyWith({String? name, String? avatar}) =>
      AppProfile(name: name ?? this.name, avatar: avatar ?? this.avatar);

  Map<String, dynamic> toJson() => {'name': name, 'avatar': avatar};

  static AppProfile fromJson(Map<String, dynamic> json) => AppProfile(
        name: (json['name'] as String?) ?? '',
        avatar: (json['avatar'] as String?) ?? '🦊',
      );
}

class StoredSession {
  const StoredSession({
    required this.roomId,
    required this.code,
    required this.memberId,
    required this.token,
    required this.expiresAt,
    required this.role,
  });

  final String roomId;
  final String code;
  final String memberId;
  final String token;
  final DateTime expiresAt;
  final String role;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'code': code,
        'memberId': memberId,
        'token': token,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
        'role': role,
      };

  static StoredSession? fromJson(Map<String, dynamic> json) {
    final roomId = json['roomId'] as String?;
    final code = json['code'] as String?;
    final memberId = json['memberId'] as String?;
    final token = json['token'] as String?;
    final expires = (json['expiresAt'] as num?)?.toInt();
    if (roomId == null || code == null || memberId == null || token == null || expires == null) {
      return null;
    }
    return StoredSession(
      roomId: roomId,
      code: code,
      memberId: memberId,
      token: token,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expires),
      role: (json['role'] as String?) ?? 'guest',
    );
  }
}

/// Small preferences wrapper. Everything is local except the room itself.
class Prefs {
  Prefs._(this._prefs);

  final SharedPreferences _prefs;

  static const _nameKey = 'profile.name';
  static const _avatarKey = 'profile.avatar';
  static const _unitsKey = 'settings.units';
  static const _serverKey = 'settings.server';
  static const _glassKey = 'settings.reduceGlass';
  static const _motionKey = 'settings.reduceMotion';
  static const _tvKey = 'settings.forceTv';
  static const _themeKey = 'settings.theme';
  static const _sessionKey = 'session.current';
  static const _recentKey = 'rooms.recent';

  static Future<Prefs> load() async => Prefs._(await SharedPreferences.getInstance());

  AppProfile get profile => AppProfile(
        name: _prefs.getString(_nameKey) ?? '',
        avatar: _prefs.getString(_avatarKey) ?? '🦊',
      );

  Future<void> saveProfile(AppProfile profile) async {
    await _prefs.setString(_nameKey, profile.name);
    await _prefs.setString(_avatarKey, profile.avatar);
  }

  UnitSystem get units => unitSystemFrom(_prefs.getString(_unitsKey));

  Future<void> saveUnits(UnitSystem units) =>
      _prefs.setString(_unitsKey, unitSystemName(units));

  String? get serverOverride => _prefs.getString(_serverKey);

  Future<void> saveServerOverride(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await _prefs.remove(_serverKey);
    } else {
      await _prefs.setString(_serverKey, url.trim());
    }
  }

  bool get reduceGlass => _prefs.getBool(_glassKey) ?? false;

  Future<void> saveReduceGlass(bool value) => _prefs.setBool(_glassKey, value);

  bool get reduceMotion => _prefs.getBool(_motionKey) ?? false;

  Future<void> saveReduceMotion(bool value) => _prefs.setBool(_motionKey, value);

  bool? get forceTv {
    if (!_prefs.containsKey(_tvKey)) return null;
    return _prefs.getBool(_tvKey);
  }

  Future<void> saveForceTv(bool? value) async {
    if (value == null) {
      await _prefs.remove(_tvKey);
    } else {
      await _prefs.setBool(_tvKey, value);
    }
  }

  ThemeMode get themeMode {
    final raw = _prefs.getString(_themeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) => _prefs.setString(_themeKey, mode.name);

  StoredSession? get session {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return StoredSession.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return null;
  }

  Future<void> saveSession(StoredSession? session) async {
    if (session == null) {
      await _prefs.remove(_sessionKey);
    } else {
      await _prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    }
  }

  List<String> get recentCodes => _prefs.getStringList(_recentKey) ?? const [];

  Future<void> rememberCode(String code) async {
    final list = [...recentCodes.where((c) => c != code)];
    list.insert(0, code);
    await _prefs.setStringList(_recentKey, list.take(5).toList());
  }

  Future<void> clearRecent() => _prefs.remove(_recentKey);
}
