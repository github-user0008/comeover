import 'package:comeover/core/config.dart';
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
  isAndroid: false,
  isIOS: false,
  demoLocation: null,
  previewMode: true,
);

final now = DateTime(2026, 11, 5, 12, 0);

Member member({
  required String id,
  required String name,
  required bool isHost,
  LatLng? point,
}) => Member(
  id: id,
  name: name,
  avatar: isHost ? '🏠' : '🐼',
  colorHex: '#CDBDFF',
  isHost: isHost,
  online: true,
  location: point == null
      ? null
      : MemberLocation(
          point: point,
          accuracy: 6,
          timestamp: now,
        ),
  receivedAt: point == null ? null : now,
  hasLocation: point != null,
);

Future<AppController> hostController({required Member guest}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await Prefs.load();
  final app = AppController(baseConfig: testConfig, prefs: prefs);
  final me = member(id: 'host', name: 'Maya Chen', isHost: true);
  app
    ..stage = AppStage.hosting
    ..now = now
    ..room = RoomModel(
      id: 'room-1',
      code: 'ABC234',
      hostId: 'host',
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 6)),
    )
    ..me = me
    ..members = [me, guest];
  return app;
}

void main() {
  test('guest first location promotes hosting → live when join was missed',
      () async {
    // The host missed the `member:joined` broadcast (its socket was still
    // connecting when the guest's REST join landed), so the guest exists in
    // the snapshot but has no location yet. Nothing can transition the lobby…
    final app = await hostController(
      guest: member(id: 'guest', name: 'Sam Rivera', isHost: false),
    );
    expect(app.stage, AppStage.hosting);

    // …until the guest's first `member:location` push arrives.
    app.ingestMemberLocation(
      'guest',
      MemberLocation(
        point: const LatLng(51.5057, -0.1246),
        accuracy: 6,
        timestamp: now,
      ),
    );

    expect(app.stage, AppStage.live);
  });

  test('host location updates do not promote the lobby', () async {
    final app = await hostController(
      guest: member(id: 'guest', name: 'Sam Rivera', isHost: false),
    );
    app.ingestMemberLocation(
      'host',
      MemberLocation(
        point: const LatLng(51.5007, -0.1246),
        accuracy: 6,
        timestamp: now,
      ),
    );
    expect(app.stage, AppStage.hosting);
  });
}
