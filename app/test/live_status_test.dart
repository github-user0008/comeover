import 'package:comeover/core/config.dart';
import 'package:comeover/data/live_status.dart';
import 'package:comeover/data/prefs.dart';
import 'package:comeover/models/member.dart';
import 'package:comeover/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const testConfig = AppConfig(
  serverUrl: 'http://localhost:8787',
  publicUrl: 'http://localhost:8787',
  isWeb: false,
  isAndroid: true,
  isIOS: false,
  demoLocation: null,
  previewMode: true,
);

final now = DateTime(2026, 10, 31, 20, 30);

Member member({
  required String id,
  required String name,
  required bool isHost,
  LatLng? point,
  DateTime? receivedAt,
}) => Member(
  id: id,
  name: name,
  avatar: isHost ? '🏠' : '🐼',
  colorHex: '#CDBDFF',
  isHost: isHost,
  online: true,
  location: point == null
      ? null
      : MemberLocation(point: point, accuracy: 6, timestamp: receivedAt ?? now),
  receivedAt: point == null ? null : (receivedAt ?? now),
  hasLocation: point != null,
);

Future<AppController> controllerWith({
  required Member me,
  required List<Member> members,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await Prefs.load();
  final app = AppController(baseConfig: testConfig, prefs: prefs);
  app
    ..stage = AppStage.live
    ..now = now
    ..room = RoomModel(
      id: 'room-1',
      code: 'ABC234',
      hostId: me.isHost ? me.id : members.firstWhere((m) => m.isHost).id,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 6)),
    )
    ..me = me
    ..members = [me, ...members];
  return app;
}

void main() {
  test('inactive outside a live room', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    final app = AppController(baseConfig: testConfig, prefs: prefs);
    final snapshot = buildLiveStatus(app);
    expect(snapshot.active, isFalse);
    expect(snapshot.phase, 'idle');
    expect(snapshot.signature, contains('idle'));
  });

  test('travelling snapshot carries distance, ETA and countdown', () async {
    final me = member(
      id: 'host',
      name: 'Maya Chen',
      isHost: true,
      point: const LatLng(51.5007, -0.1246),
    );
    final guest = member(
      id: 'guest',
      name: 'Sam Rivera',
      isHost: false,
      point: const LatLng(51.5057, -0.1246),
    );
    final app = await controllerWith(me: me, members: [guest]);
    final snapshot = buildLiveStatus(app);

    expect(snapshot.active, isTrue);
    expect(snapshot.phase, 'travelling');
    expect(snapshot.title, startsWith('Sam is '));
    expect(snapshot.title, contains('away'));
    expect(snapshot.distance, isNotEmpty);
    expect(snapshot.eta, isNotEmpty);
    expect(snapshot.shortText, isNotEmpty);
    expect(snapshot.memberName, 'Sam Rivera');
    expect(snapshot.memberAvatar, '🐼');
    expect(snapshot.roomCode, 'ABC234');
    expect(snapshot.progress, inInclusiveRange(0, 1));
    expect(snapshot.arrivalAt, isNotNull);
    expect(snapshot.arrivalAt!.isAfter(now), isTrue);
  });

  test('arrived snapshot switches to the door message', () async {
    final me = member(
      id: 'host',
      name: 'Maya Chen',
      isHost: true,
      point: const LatLng(51.5007, -0.1246),
    );
    final guest = member(
      id: 'guest',
      name: 'Sam Rivera',
      isHost: false,
      point: const LatLng(51.50075, -0.1246),
    );
    final app = await controllerWith(me: me, members: [guest]);
    final snapshot = buildLiveStatus(app);

    expect(snapshot.phase, 'arrived');
    expect(snapshot.arrived, isTrue);
    expect(snapshot.title, 'Sam is here');
    expect(snapshot.shortText, 'Here');
    expect(snapshot.progress, 1);
    expect(snapshot.arrivalAt, isNull);
  });

  test('waiting snapshot names the person who has not shared yet', () async {
    final me = member(
      id: 'host',
      name: 'Maya Chen',
      isHost: true,
      point: const LatLng(51.5007, -0.1246),
    );
    final guest = member(id: 'guest', name: 'Sam Rivera', isHost: false);
    final app = await controllerWith(me: me, members: [guest]);
    final snapshot = buildLiveStatus(app);

    expect(snapshot.phase, 'waiting');
    expect(snapshot.title, 'Waiting for Sam');
    expect(snapshot.shortText, 'Waiting');
    expect(snapshot.progress, 0);
    expect(snapshot.arrivalAt, isNull);
  });

  test('waiting snapshot explains the invite when the room is empty', () async {
    final me = member(
      id: 'host',
      name: 'Maya Chen',
      isHost: true,
      point: const LatLng(51.5007, -0.1246),
    );
    final app = await controllerWith(me: me, members: const []);
    final snapshot = buildLiveStatus(app);

    expect(snapshot.phase, 'waiting');
    expect(snapshot.title, 'Room ABC234 is open');
    expect(snapshot.shortText, 'Live');
  });

  test(
    'signature ignores the ticking clock but notices real changes',
    () async {
      final me = member(
        id: 'host',
        name: 'Maya Chen',
        isHost: true,
        point: const LatLng(51.5007, -0.1246),
      );
      final guest = member(
        id: 'guest',
        name: 'Sam Rivera',
        isHost: false,
        point: const LatLng(51.5057, -0.1246),
      );
      final app = await controllerWith(me: me, members: [guest]);
      final first = buildLiveStatus(app);

      app.now = now.add(const Duration(seconds: 1));
      final second = buildLiveStatus(app);
      expect(second.signature, first.signature);

      app.members = [
        me,
        member(
          id: 'guest',
          name: 'Sam Rivera',
          isHost: false,
          point: const LatLng(51.5047, -0.1246),
        ),
      ];
      final third = buildLiveStatus(app);
      expect(third.signature, isNot(first.signature));
    },
  );
}
