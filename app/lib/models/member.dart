import 'package:latlong2/latlong.dart';

import '../core/format.dart';

class MemberLocation {
  const MemberLocation({
    required this.point,
    required this.accuracy,
    required this.timestamp,
    this.heading,
    this.speed,
    this.battery,
  });

  final LatLng point;
  final double accuracy;
  final DateTime timestamp;
  final double? heading;
  final double? speed;
  final double? battery;

  factory MemberLocation.fromJson(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
  }) {
    final ts = json['ts'];
    return MemberLocation(
      point: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0,
        (json['lng'] as num?)?.toDouble() ?? 0,
      ),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 25,
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      battery: (json['battery'] as num?)?.toDouble(),
      timestamp:
          receivedAt ??
          (ts is num
              ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
              : DateTime.now()),
    );
  }

  MemberLocation copyWith({LatLng? point, DateTime? timestamp}) =>
      MemberLocation(
        point: point ?? this.point,
        accuracy: accuracy,
        timestamp: timestamp ?? this.timestamp,
        heading: heading,
        speed: speed,
        battery: battery,
      );
}

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.avatar,
    required this.colorHex,
    required this.isHost,
    required this.online,
    this.device = 'phone',
    this.demo = false,
    this.location,
    this.receivedAt,
    this.hasLocation = false,
  });

  final String id;
  final String name;
  final String avatar;
  final String colorHex;
  final String device;
  final bool isHost;
  final bool demo;
  final bool online;
  final MemberLocation? location;

  /// When this app last heard from the member (drives "stale" messaging).
  final DateTime? receivedAt;

  /// True when the relay knows a position, even if approximate precision
  /// rounded it into a coarse cell.
  final bool hasLocation;

  bool get isTv => device == 'tv';
  bool get canTrack => location != null;

  factory Member.fromJson(Map<String, dynamic> json, {DateTime? receivedAt}) {
    final rawLocation = json['location'];
    MemberLocation? location;
    if (rawLocation is Map<String, dynamic>) {
      location = MemberLocation.fromJson(
        rawLocation,
        receivedAt: receivedAt ?? DateTime.now(),
      );
    } else if (rawLocation is Map) {
      location = MemberLocation.fromJson(
        rawLocation.cast<String, dynamic>(),
        receivedAt: receivedAt ?? DateTime.now(),
      );
    }
    return Member(
      id: json['id']?.toString() ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Someone',
      avatar: (json['avatar'] as String?) ?? '🙂',
      colorHex: (json['color'] as String?) ?? '#CDBDFF',
      device: (json['device'] as String?) ?? 'phone',
      isHost: json['isHost'] == true,
      demo: json['demo'] == true,
      online: json['online'] != false,
      location: location,
      receivedAt: location != null ? (receivedAt ?? DateTime.now()) : null,
      hasLocation: location != null,
    );
  }

  Member withLocation(
    MemberLocation? next, {
    DateTime? receivedAt,
    bool? online,
  }) => Member(
    id: id,
    name: name,
    avatar: avatar,
    colorHex: colorHex,
    device: device,
    isHost: isHost,
    demo: demo,
    online: online ?? this.online,
    location: next ?? location,
    receivedAt: next != null ? (receivedAt ?? DateTime.now()) : this.receivedAt,
    hasLocation: next != null || hasLocation,
  );

  Member copyWith({
    bool? online,
    String? name,
    String? avatar,
    String? device,
  }) => Member(
    id: id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    colorHex: colorHex,
    device: device ?? this.device,
    isHost: isHost,
    demo: demo,
    online: online ?? this.online,
    location: location,
    receivedAt: receivedAt,
    hasLocation: hasLocation,
  );
}

class RoomSettings {
  const RoomSettings({
    this.units = UnitSystem.metric,
    this.precision = 'exact',
    this.arrivalRadius = 40,
  });

  final UnitSystem units;
  final String precision;
  final double arrivalRadius;

  bool get isApproximate => precision == 'approximate';

  factory RoomSettings.fromJson(Map<String, dynamic> json) => RoomSettings(
    units: unitSystemFrom(json['units'] as String?),
    precision: (json['precision'] as String?) ?? 'exact',
    arrivalRadius: (json['arrivalRadius'] as num?)?.toDouble() ?? 40,
  );

  RoomSettings copyWith({
    UnitSystem? units,
    String? precision,
    double? arrivalRadius,
  }) => RoomSettings(
    units: units ?? this.units,
    precision: precision ?? this.precision,
    arrivalRadius: arrivalRadius ?? this.arrivalRadius,
  );
}

class RoomModel {
  const RoomModel({
    required this.id,
    required this.code,
    required this.hostId,
    required this.createdAt,
    required this.expiresAt,
    this.ended = false,
    this.settings = const RoomSettings(),
  });

  final String id;
  final String code;
  final String hostId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool ended;
  final RoomSettings settings;

  factory RoomModel.fromJson(Map<String, dynamic> json) => RoomModel(
    id: json['id']?.toString() ?? '',
    code: (json['code'] as String?) ?? '',
    hostId: json['hostId']?.toString() ?? '',
    createdAt: _date(json['createdAt']),
    expiresAt: _date(json['expiresAt']),
    ended: json['ended'] == true,
    settings: json['settings'] is Map
        ? RoomSettings.fromJson(
            (json['settings'] as Map).cast<String, dynamic>(),
          )
        : const RoomSettings(),
  );

  RoomModel copyWith({RoomSettings? settings, bool? ended}) => RoomModel(
    id: id,
    code: code,
    hostId: hostId,
    createdAt: createdAt,
    expiresAt: expiresAt,
    ended: ended ?? this.ended,
    settings: settings ?? this.settings,
  );

  static DateTime _date(Object? value) {
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.now();
  }
}

class RoomSession {
  const RoomSession({
    required this.room,
    required this.me,
    required this.members,
    required this.token,
  });

  final RoomModel room;
  final Member me;
  final List<Member> members;
  final String token;
}

String memberColor(Member member) => member.colorHex;
